local cagate = require("resty.cagate")
if cagate.verify_method() == false
then
    return
end

local base_api = {
    dict = function ()
        
    end
}

local api = base_api[ngx.var.api]
if api == nil
then
    cagate.resp_forbidden()
    return
end

api()