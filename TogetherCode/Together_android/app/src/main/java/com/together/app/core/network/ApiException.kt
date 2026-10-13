package com.together.app.core.network

/** 统一业务异常 */
sealed class ApiException(message: String) : Exception(message) {
    /** 网络错误（无连接、超时等） */
    class Network(message: String = "网络连接失败，请检查网络") : ApiException(message)

    /** 数据解析错误 */
    class Parse(message: String = "数据解析失败") : ApiException(message)

    /** 登录态失效 */
    class Unauthorized(message: String = "登录已过期，请重新登录") : ApiException(message)

    /** 业务错误（后端返回 code != 0） */
    class Business(val code: Int, message: String) : ApiException(message)
}