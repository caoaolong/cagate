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
    -- 测试database连接是否可用
    local err = cagate.test_conn(configValue["db"], "mysql")
    if err then
        cagate.resp_servererror(err)
        return
    end
    -- 测试redis连接是否可用
    err = cagate.test_conn(configValue["redis"], "redis")
    if err then
        cagate.resp_servererror(err)
        return
    end
    -- 更新缓存
    local dict = ngx.shared.cagate
    dict:set("dbConfig", configValue["db"])
    dict:set("redisConfig", configValue["redis"])
    -- 写入文件
    local config = nil
    config, err = io.open(dict:get("config"), "w")
    if not config then
        cagate.resp_servererror(err)
        return
    end
    config:write(cjson.encode(configValue))
    config:close()
    -- 装载配置
    err = cagate.load_config()
    if err then
        cagate.resp_servererror(err)
        return
    end
    cagate.resp(cagate.status.ok, "write database settings successed!")
end

settings_api.cache_settings = function ()
    local dict = ngx.shared.cagate
    local cjson = require("cjson")
    cagate.resp(cagate.status.ok, "load cache settings successed!", {
        db = cjson.decode(dict:get("dbConfig")),
        redis = cjson.decode(dict:get("redisConfig")),
        sys = cjson.decode(dict:get("sysConfig"))
    })
end

local api = settings_api[ngx.var.api]
if api == nil
then
    cagate.resp_forbidden()
    return
end

api()