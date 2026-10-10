import { View, Image, Text } from '@tarojs/components'
import Taro from '@tarojs/taro'
import { useState, useEffect } from 'react'
import './index.scss'

// 图标资源（编译后由 webpack 处理路径）
import homeIcon from '../assets/tabbar/home.png'
import homeActiveIcon from '../assets/tabbar/home-active.png'
import plazaIcon from '../assets/tabbar/plaza.png'
import plazaActiveIcon from '../assets/tabbar/plaza-active.png'
import publishIcon from '../assets/tabbar/publish.png'
import messageIcon from '../assets/tabbar/message.png'
import messageActiveIcon from '../assets/tabbar/message-active.png'
import mineIcon from '../assets/tabbar/mine.png'
import mineActiveIcon from '../assets/tabbar/mine-active.png'

/** Tab 项配置 */
interface TabItem {
  pagePath: string
  text: string
  icon: string
  selectedIcon: string
}

const TAB_LIST: TabItem[] = [
  { pagePath: '/pages/home/index', text: '首页', icon: homeIcon, selectedIcon: homeActiveIcon },
  { pagePath: '/pages/plaza/index', text: '广场', icon: plazaIcon, selectedIcon: plazaActiveIcon },
  { pagePath: '/pages/publish/index', text: '发布', icon: publishIcon, selectedIcon: publishIcon },
  { pagePath: '/pages/messages/index', text: '消息', icon: messageIcon, selectedIcon: messageActiveIcon },
  { pagePath: '/pages/mine/index', text: '我的', icon: mineIcon, selectedIcon: mineActiveIcon },
]

/** 发布按钮在 TAB_LIST 中的索引 */
const PUBLISH_INDEX = 2

export default function CustomTabBar() {
  const [selected, setSelected] = useState(0)

  useEffect(() => {
    // 页面显示时同步当前 tab 索引
    const onShow = () => {
      const page = Taro.getCurrentPages().pop()
      if (!page) return
      const route = '/' + page.route
      const idx = TAB_LIST.findIndex(t => t.pagePath === route)
      if (idx >= 0 && idx !== PUBLISH_INDEX) {
        setSelected(idx)
      }
    }
    // 首次挂载同步
    onShow()
    // 监听页面切换（Taro 事件）
    Taro.eventCenter.on('onTabBarRefresh', onShow)
    return () => {
      Taro.eventCenter.off('onTabBarRefresh', onShow)
    }
  }, [])

  const handleTabClick = (index: number) => {
    // 点击发布按钮：navigateTo 发布页，不切换 tab
    if (index === PUBLISH_INDEX) {
      Taro.navigateTo({ url: '/packageSocial/pages/post-create/index' })
      return
    }
    // 其他 tab：正常切换
    setSelected(index)
    Taro.switchTab({ url: TAB_LIST[index].pagePath })
  }

  return (
    <View className='custom-tab-bar'>
      {TAB_LIST.map((tab, index) => {
        const isPublish = index === PUBLISH_INDEX
        const isActive = selected === index && !isPublish

        return (
          <View
            key={tab.pagePath}
            className={`tab-item ${isPublish ? 'tab-item--publish' : ''}`}
            onClick={() => handleTabClick(index)}
          >
            {isPublish ? (
              // 发布按钮：突出的大加号样式
              <View className='publish-btn'>
                <Image className='publish-icon' src={tab.icon} mode='aspectFit' />
              </View>
            ) : (
              <>
                <Image
                  className='tab-icon'
                  src={isActive ? tab.selectedIcon : tab.icon}
                  mode='aspectFit'
                />
                <Text className={`tab-text ${isActive ? 'tab-text--active' : ''}`}>
                  {tab.text}
                </Text>
              </>
            )}
          </View>
        )
      })}
    </View>
  )
}