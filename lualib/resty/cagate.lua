module = {
    method = {
        get = "GET", post = "POST", put = "PUT", delete = "DELETE"
    },
    status = {
        forbidden = 403, badrequest = 400, notfound = 404, ok = 200
    }
}

local cjson = require("cjson")
function module.resp(code, msg)
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

return module