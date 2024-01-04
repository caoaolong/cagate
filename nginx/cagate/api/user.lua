local cagate = require("resty.cagate")
if cagate.verify_method() == false
then
    return
end

local user_api = {
    login = function ()
        local params = cagate.req(ngx.req.get_body_data())
        
        cagate.resp(cagate.status.ok, "Login!")
    end
}

local api = user_api[ngx.var.api]
if api == nil
then
    cagate.resp_forbidden()
    return
end

api()