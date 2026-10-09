import type { UserConfigExport } from '@tarojs/cli';
export default {
  logger: {
    quiet: false,
    stats: true,
  },
  mini: {},
  h5: {
    devServer: {
      open: false, //禁止自动打开浏览器
      client: {
        // sass @import 弃用等历史 warning 不弹全屏遮罩，仅真正的编译错误才覆盖
        overlay: {
          errors: true,
          warnings: false,
          runtimeErrors: true,
        },
      },
    },
  },
} satisfies UserConfigExport<'webpack5'>;
