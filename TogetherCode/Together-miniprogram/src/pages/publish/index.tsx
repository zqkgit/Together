import { View } from '@tarojs/components'

/**
 * 发布占位页（tabBar 必须注册页面，但 custom-tab-bar 已拦截点击，
 * 此页不会实际展示，navigateTo 直接跳转 /packageSocial/pages/post-create/index）
 */
export default function PublishPage() {
  return <View />
}