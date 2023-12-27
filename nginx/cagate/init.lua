local cjson = require("cjson")
local config, err = io.open(ngx.config.prefix() .. "cagate/cagate.json", "r")
if config then
    local content = config:read("*a")
    local data = cjson.decode(content)
    if data then
        ngx.log(ngx.INFO, data["user"])
    end
    io.close()
else
    ngx.log(ngx.ERR, err)
end

local dict = ngx.shared.cagate
dict:set("name", "Cagate Service")

ngx.log(ngx.INFO, "Openresty Initilized!")