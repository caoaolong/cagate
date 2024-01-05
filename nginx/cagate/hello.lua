local cagate = require("resty.cagate")
local uuid = cagate.uuid()
ngx.say(uuid)
ngx.say(#uuid)