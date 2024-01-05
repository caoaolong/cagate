local config_path = ngx.config.prefix() .. "cagate/cagate.json"
-- 保存数据
local dict = ngx.shared.cagate
dict:set("config", config_path)
-- 读取数据库配置
local config, err = io.open(config_path, "r")
if config then
    local dbConfig = config:read("a")
    if dbConfig then
        dict:set("dbConfig", dbConfig)
    end
    io.close()
else
    ngx.log(ngx.ERR, err)
end