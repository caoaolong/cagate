local jwt = require("resty.jwt")
module = {
    secret = "cagate-jwt",
    method = {
        get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    },
    status = {
        forbidden = 403, badrequest = 400, vertificationfailed = 401, notfound = 404, ok = 200,
        servererror = 500
    },
    sqls = {
        cg_user_insert = "INSERT INTO cg_user(user_id, nickname, username, password, phone, email, token) VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s')",
        cg_user_select = "SELECT * FROM cg_user WHERE %s = '%s' LIMIT 1",
        cg_user_update = "UPDATE cg_user SET %s = '%s' WHERE %s = '%s'"
    }
}

local cjson = require("cjson")
function module.resp(code, msg, data)
    if data then
        ngx.say(cjson.encode({
            code = code,
            msg = msg,
            data = data
        }))
        return
    end
    ngx.say(cjson.encode({
        code = code,
        msg = msg
    }))
end

function module.resp_forbidden()
    ngx.say(cjson.encode({
        code = module.status.forbidden,
        msg = 'Forbidden'
    }))
end

function module.resp_badrequest(msg)
    ngx.say(cjson.encode({
        code = module.status.badrequest,
        msg = msg or 'Bad Request'
    }))
end

function module.resp_servererror(err)
    ngx.say(cjson.encode({
        code = module.status.servererror,
        msg = err
    }))
end

function module.resp_refreshtoken(token)
    ngx.say(cjson.encode({
        code = module.status.ok,
        token = token
    }))
end

function module.req(body)
    return cjson.decode(body)
end

function module.get_password(password)
    local sha256 = require("resty.sha256")
    local encoder = sha256:new()
    encoder:update(password)
    local digest = encoder:final()
    return ngx.encode_base64(digest)
end

function module.verify_method(m)
    m = m or module.method.post
    if m ~= ngx.req.get_method()
    then
        ngx.say(module.resp_forbidden())
        return false
    end
    return true
end

function module.verify_token(token)
    local err = nil
    local value = jwt:verify(module.secret, token)
    -- 验证token是否有效
    if value["verified"] and value["valid"] then
        local payload = value["payload"]
        -- 验证token是否过期
        if os.time() <= payload["expiry"] then
            return token, payload, nil
        end
        -- 如果配置了自动刷新则刷新
        if module.get_config("token-auto-refresh") == "true" then
            local newToken = nil
            newToken, payload, err = module.refresh_token(payload)
            if err then
                return nil, nil, err
            end
            return newToken, payload, nil
        end
        return nil, nil, "token expired"
    end
    return nil, nil, "token is not available"
end

function module.refresh_token(payload)
    payload["expiry"] = os.time() + tonumber(module.get_config("token-expiry"))
    local token = jwt:sign(module.secret, {
        header = {
            typ = "JWT", alg = module.get_config("token-encoder")
        },
        payload = payload
    })
    local conn, err = module.get_conn()
    if not conn then
        return nil, nil, err
    end
    local resp = nil
    resp, err = module.exec(conn, "cg_user_update", "token", token, "user_id", payload["user_id"])
    if not resp then
        return nil, nil, err
    end
    return token, payload, nil
end

function module.test_conn(dbConfig, type)
    if type == "db" then
        local mysql = require("resty.mysql")
        local c, err = mysql:new()
        if not c then
            return err
        end
        local db, err = c:connect(dbConfig)
        if not db then
            return err
        end
        return nil
    elseif type == "redis" then
        local redis = require("resty.redis")
        local c = redis:new()
        local ok, err = c:connect(dbConfig["host"], tonumber(dbConfig["port"]))
        if not ok then
            return err
        end
        if dbConfig["password"] and #dbConfig["password"] > 0 then
            local conn = nil
            conn, err = c:auth(dbConfig["password"])
            if not conn then
                return err
            end
        end
        return nil
    end
end

function module.get_conn(type)
    type = type or "db"
    if type == "db" then
        local dict = ngx.shared.cagate
        -- 连接数据库
        local mysql = require("resty.mysql")
        local db, err = mysql:new()
        if not db then
            return nil, err
        end
        db:set_timeout(1000)
        db:set_keepalive(1000, 100)
        local ok, err = db:connect(cjson.decode(dict:get("dbConfig")))
        if not ok then
            return nil, err
        end
        return db, nil
    elseif type == "redis" then
        local dict = ngx.shared.cagate
        local redis = require("resty.redis")
        local c = redis:new()
        local redisConfig = cjson.decode(dict:get("redisConfig"))
        local ok, err = c:connect(redisConfig["host"], tonumber(redisConfig["port"]))
        if not ok then
            return nil, err
        end
        if redisConfig["password"] and #redisConfig["password"] > 0 then
            local conn = nil
            conn, err = c:auth(redisConfig["password"])
            if not conn then
                return nil, err
            end
            return c, nil
        end
        return c, nil
    end
    return nil, "Invalid type!"
end

function module.load_config()
    local db, err = module.get_conn()
    if not db then
        return err
    end
    -- 读取配置
    local resp = nil
    resp, err = db:query("SELECT config_type, config_value FROM cg_config")
    if err or not resp then
        return err
    end
    local dict = ngx.shared.cagate
    -- 装载配置
    local json = require("cjson")
    dict:set("sysConfig", json.encode(resp))
    return nil
end

function module.get_config(name)
    local dict = ngx.shared.cagate
    local json = require("cjson")
    local config = json.decode(dict:get("sysConfig"))
    for i, v in ipairs(config) do
        if v["config_type"] == name then
            return v["config_value"]
        end
    end
    return nil
end

function module.exec(db, name, ...)
    local sql = string.format(module.sqls[name], ...)
    local resp, err = db:query(sql)
    if err then
        return nil, err
    end
    return resp, nil
end

function module.uuid()
    local template ='xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'
    return string.upper(string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

function module.redis_set()

end

function module.redis_get()
end

return module