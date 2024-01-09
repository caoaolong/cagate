local config_path = ngx.config.prefix() .. "cagate/cagate.json"
-- 保存数据
local dict = ngx.shared.cagate
dict:set("config", config_path)
-- 读取数据库配置
local config, err = io.open(config_path, "r")
if config then
    local configValue = config:read("a")
    if configValue then
        local cjson = require("cjson")
        local value = cjson.decode(configValue)
        dict:set("dbConfig", cjson.encode(value["db"]))
        dict:set("redisConfig", cjson.encode(value["redis"]))
    end
    io.close()
else
    ngx.log(ngx.ERR, err)
end