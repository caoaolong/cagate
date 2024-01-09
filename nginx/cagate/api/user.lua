local cagate = require("resty.cagate")
if not cagate.verify_method() then
    return
end

local user_api = {}

user_api.login = function ()
    local params = cagate.req(ngx.req.get_body_data())
    -- 校验参数
    if not params or params["username"] == "" or params["password"] == "" then
        cagate.resp_badrequest()
    end
    -- 检查是否已经登录
    local conn, err = cagate.get_conn("redis")
    if not conn then
        cagate.resp_servererror(err)
        return
    end
    local token = nil
    local redisKey = "user.token." .. params["username"]
    token, err = conn:get(redisKey)
    if token ~= ngx.null then
        local jwt = require("resty.jwt")
        local object = jwt:load_jwt(token, cagate.secret)
        cagate.resp(cagate.status.ok, "[cache] cagate account sign up successful!", {
            data = object["payload"],
            token = token
        })
        return
    end
    -- 连接数据库
    conn, err = cagate.get_conn()
    if not conn then
        cagate.resp_servererror(err)
        return
    end
    -- 查询用户数据
    local resp = nil
    resp, err = cagate.exec(conn, "cg_user_select", "username", params["username"])
    if not resp then
        cagate.resp_servererror(err)
        return
    end
    resp = resp[1]
    local userPassword = cagate.get_password(params["password"])
    -- 判断密码是否一致
    if userPassword == resp["password"] then
        -- 判断token是否过期
        local payload = nil
        token, payload, err = cagate.verify_token(resp["token"])
        if err then
            cagate.resp_servererror(err)
            return
        end
        -- 保存用户token
        conn = cagate.get_conn("redis")
        conn:set(redisKey, token)
        local expiry = tonumber(payload["expiry"])
        ngx.log(ngx.INFO, "redisKey: " .. redisKey .. " Expiry: " .. (expiry - os.time()))
        conn:expire(redisKey, expiry - os.time())
        -- 返回数据
        cagate.resp(cagate.status.ok, "[first] cagate account sign up successful!", {
            data = payload,
            token = token
        })
        return
    end
    cagate.resp(cagate.status.vertificationfailed, "用户登录验证失败")
end

user_api.register = function ()
    local params = cagate.req(ngx.req.get_body_data())
    if params["username"] == "" or params["nickname"] == "" or params["password"] == "" then
        cagate.resp_badrequest()
        return
    end
    if #params["password"] < 6 or #params["password"] > 20 then
        cagate.resp_badrequest("密码不合法")
        return
    end
    local userId = cagate.uuid()
    local password = cagate.get_password(params["password"])
    local jwt = require("resty.jwt")
    local token = jwt:sign(cagate.secret, {
        header = {
            typ = "JWT", alg = cagate.get_config("token-encoder")
        },
        payload = {
            user_id = userId,
            username = params["username"],
            phone = params["phone"],
            email = params["email"],
            expiry = os.time() + tonumber(cagate.get_config("token-expiry"))
        }
    })
    local conn, err = cagate.get_conn()
    if not conn then
        cagate.resp_servererror(err)
        return
    end
    local resp = nil
    resp, err = cagate.exec(conn, "cg_user_insert",
        userId, params["nickname"], params["username"], password, params["phone"], params["email"], token)
    if not resp then
        cagate.resp_servererror(err)
        return
    end
    cagate.resp(cagate.status.ok, "register cagate account successful!")
end

local api = user_api[ngx.var.api]
if api == nil
then
    cagate.resp_forbidden()
    return
end

api()