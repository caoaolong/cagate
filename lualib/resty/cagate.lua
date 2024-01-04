module = {
    method = {
        get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    },
    status = {
        forbidden = 403, badrequest = 400, notfound = 404, ok = 200,
        servererror = 500
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

function module.resp_badrequest()
    ngx.say(cjson.encode({
        code = module.status.badrequest,
        msg = 'Bad Request'
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
    if _G.db then
        return _G.db, nil
    end
    local dict = ngx.shared.cagate
    -- 连接数据库
    local mysql = require("resty.mysql")
    local c, err = mysql:new()
    if not c then
        ngx.log(ngx.ERR, "数据库初始化错误: ", err)
        return nil, err
    end
    c:set_timeout(1000)
    c:set_keepalive(1000, 100)
    local db, err = c:connect(cjson.decode(dict:get("dbConfig")))
    if not db then
        ngx.log(ngx.ERR, "数据库连接错误: ", err)
        return nil, err
    end
    _G.db = db
    ngx.log(ngx.INFO, "数据库连接成功")
    return db, nil
end

return module