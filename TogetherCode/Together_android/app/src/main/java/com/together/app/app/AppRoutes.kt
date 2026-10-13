package com.together.app.app

object AppRoutes {
    const val Login = "login"
    const val PhoneLogin = "phone_login"
    const val VerifyCode = "verify_code/{phone}"

    const val ParentMain = "parent_main"
    const val TeacherMain = "teacher_main"
    const val StudioMain = "studio_main"

    fun verifyCode(phone: String) = "verify_code/$phone"
}