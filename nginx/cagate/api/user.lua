local cagate = require("resty.cagate")
if not cagate.verify_method() then
    return
end

local user_api = {}

user_api.login = function ()
    local params = cagate.req(ngx.req.get_body_data())
    if params["username"] == "" or params["password"] == "" then
        cagate.resp_badrequest()
    end
    local conn, err = cagate.get_conn()
    if not conn then
        cagate.resp_servererror(err)
        return
    end
    cagate.resp(cagate.status.ok, "cagate account sign up successful!")
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
    local jwt = require("resty.jwt")
    local token = jwt:sign("cagate-jwt", {
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
        userId, params["nickname"], params["username"], params["password"], params["phone"], params["email"], token)
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