local cagate = require("resty.cagate")
if not cagate.verify_method() then
    return
end

local settings_api = {}
-- [router] POST /cagate/set/settings
settings_api.set_settings = function ()
    -- 解析json
    local cjson = require("cjson")
    local configValue = cjson.decode(ngx.req.get_body_data())
    if configValue.host == "localhost" then
        configValue.host = "127.0.0.1"
    end
    -- 测试连接是否可用
    local cagate = require("resty.cagate")
    local err = cagate.test_conn(configValue)
    if err then
        cagate.resp_servererror(err)
        return
    end
    -- 更新缓存
    local dict = ngx.shared.cagate
    dict:set("dbConfig", configValue)
    -- 写入文件
    local dict = ngx.shared.cagate
    local config, err = io.open(dict:get("config"), "w")
    if config then
        config:write(cjson.encode(configValue))
        config:close()
        cagate.resp(cagate.status.ok, "write database settings successed!")
        return
    end
    cagate.resp_servererror(err)
end

-- [router] POST /cagate/get/settings
settings_api.get_settings = function ()
    local dict = ngx.shared.cagate
    local config, err = io.open(dict:get("config"), "r")
    if config then
        local configValue = config:read("a")
        config:close()
        local cjson = require("cjson")
        cagate.resp(cagate.status.ok, "read database settings successed!",
            cjson.decode(configValue))
        return
    end
    cagate.resp_servererror(err)
end

local api = settings_api[ngx.var.api]
if api == nil
then
    cagate.resp_forbidden()
    return
end

api()