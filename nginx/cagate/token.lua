local jwt = require("resty.jwt")

local jwt_token = jwt:sign("lua-resty-jwt",
    {
        header={typ="JWT", alg="HS256"},
        payload={foo="bar"}
    })
ngx.say(jwt_token)