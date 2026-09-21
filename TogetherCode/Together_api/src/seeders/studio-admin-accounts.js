/**
 * 为已通过认证的工作室主理人补齐 Web 后台账号（幂等，可重复执行）
 *
 * 背景：Web 端登录走独立的 admin_accounts 体系（username + bcrypt 密码），
 *      与 C 端 users（手机号 + 验证码）不通用。历史数据里只有 bootstrap-demo
 *      手工建的 platform_admin / studio_owner_1，运行时通过 App 入驻的工作室
 *      （如 13800000000 的「兰亭书画」）没有后台账号，主理人登不进 Web 端。
 *
 *      新入驻的工作室在平台审核通过时已由 adminStore.reviewStudioApplication
 *      自动开号；本脚本只用于给「本脚本上线之前」已存在的工作室补号。
 *
 * 规则：username = 主理人注册手机号，role = studio_owner，初始密码 123456。
 *
 * 执行：npm run db:seed:studio-admin（或 node src/seeders/studio-admin-accounts.js）
 */
const { sequelize, User, StudioProfile } = require("../models");
const { ensureStudioOwnerAccount } = require("../services/adminStore");

async function main() {
  const studios = await StudioProfile.findAll({
    where: { status: 1 },
    attributes: ["studio_id", "name", "user_id"]
  });

  let created = 0;
  let skipped = 0;

  for (const studio of studios) {
    if (!studio.user_id) {
      skipped += 1;
      continue;
    }
    const owner = await User.findByPk(studio.user_id, { attributes: ["phone", "nickname"] });
    if (!owner?.phone) {
      console.log(`跳过 ${studio.name}：主理人未绑定手机号`);
      skipped += 1;
      continue;
    }

    const account = await ensureStudioOwnerAccount({
      userId: studio.user_id,
      studioId: studio.studio_id
    });

    if (account) {
      console.log(`已就绪 ${studio.name} → ${account.username} / 123456（studio_owner）`);
      created += 1;
    } else {
      skipped += 1;
    }
  }

  console.log(`\n完成：处理 ${created} 个工作室后台账号，跳过 ${skipped} 个`);
}

main()
  .then(() => sequelize.close())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
