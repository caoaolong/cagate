local cagate = require("resty.cagate")
if not cagate.verify_method() then
    return
end

local user_api = {}

user_api.login = function ()
    local params = cagate.req(ngx.req.get_body_data())
    local conn, err = cagate.get_conn()
    if not conn then
        cagate.resp_servererror(err)
        return
    end
    cagate.resp(cagate.status.ok, "Login!")
end

user_api.register = function ()
    
end

local api = user_api[ngx.var.api]
if api == nil
then
    cagate.resp_forbidden()
    return
end

api()