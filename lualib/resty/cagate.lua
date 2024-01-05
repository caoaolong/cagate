module = {
    method = {
        get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    },
    status = {
        forbidden = 403, badrequest = 400, notfound = 404, ok = 200,
        servererror = 500
    },
    sqls = {
        cg_user_insert = "INSERT INTO cg_user(user_id, nickname, username, password, phone, email, token) VALUES('%s', '%s', '%s', '%s', '%s', '%s', '%s')"
    }
}

local cjson = require("cjson")
function module.resp(code, msg, data)
    if data then
        ngx.say(cjson.encode({
            code = code,
            msg = msg,
            data = data
        }))
        return
    end
    ngx.say(cjson.encode({
        code = code,
        msg = msg
    }))
end

function module.resp_forbidden()
    ngx.say(cjson.encode({
        code = module.status.forbidden,
        msg = 'Forbidden'
    }))
end

function module.resp_badrequest(msg)
    ngx.say(cjson.encode({
        code = module.status.badrequest,
        msg = msg or 'Bad Request'
    }))
end

function module.resp_servererror(err)
    ngx.say(cjson.encode({
        code = module.status.servererror,
        msg = err
    }))
end

function module.req(body)
    return cjson.decode(body)
end

function module.verify_method(m)
    m = m or module.method.post
    if m ~= ngx.req.get_method()
    then
        ngx.say(module.resp_forbidden())
        return false
    end
    return true
end

function module.test_conn(dbConfig)
    local mysql = require("resty.mysql")
    local c, err = mysql:new()
    if not c then
        return err
    end
    ngx.log(ngx.INFO, "测试连接: ", cjson.encode(dbConfig))
    local db, err = c:connect(dbConfig)
    if not db then
        return err
    end
    return nil
end

function module.get_conn()
    local dict = ngx.shared.cagate
    -- 连接数据库
    local mysql = require("resty.mysql")
    local db, err = mysql:new()
    if not db then
        return nil, err
    end
    db:set_timeout(1000)
    db:set_keepalive(1000, 100)
    local ok, err = db:connect(cjson.decode(dict:get("dbConfig")))
    if not ok then
        return nil, err
    end
    return db, nil
end

function module.load_config()
    local db, err = module.get_conn()
    if not db then
        return err
    end
    -- 读取配置
    local resp = nil
    resp, err = db:query("SELECT config_type, config_value FROM cg_config")
    if err or not resp then
        return err
    end
    local dict = ngx.shared.cagate
    -- 装载配置
    local json = require("cjson")
    dict:set("sysConfig", json.encode(resp))
    return nil
end

function module.get_config(name)
    local dict = ngx.shared.cagate
    local json = require("cjson")
    local config = json.decode(dict:get("sysConfig"))
    for i, v in ipairs(config) do
        if v["config_type"] == name then
            return v["config_value"]
        end
    end
    return nil
end

function module.exec(db, name, ...)
    local sql = string.format(module.sqls[name], ...)
    local resp, err = db:query(sql)
    if err then
        return nil, err
    end
    return resp, nil
end

function module.uuid()
    local template ='xxxxxxxxxxxx4xxxyxxxxxxxxxxxxxxx'
    return string.upper(string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end))
end

return module