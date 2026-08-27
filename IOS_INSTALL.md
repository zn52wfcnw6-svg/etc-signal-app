# iOS安装指南（iPhone）

## 最简方案：GitHub自动构建（推荐）

你不需要Mac，不需要写代码，只需3步。

### 第一步：注册GitHub账号

1. 打开 https://github.com
2. 注册一个免费账号
3. 登录

### 第二步：上传代码

1. GitHub首页点右上角 **+** → **New repository**
2. Repository name 填：`etc-signal-app`
3. 选 **Public**（公开，免费额度够用）
4. 点 **Create repository**
5. 在创建好的仓库页面，点 **uploading an existing file**
6. 把解压后的 `etc_signal_app` 文件夹里的**所有文件**拖进去（注意是文件夹里面的文件，不是文件夹本身）
7. 拉到最下面点 **Commit changes**

### 第三步：等待自动构建并下载

1. 上传完成后，点仓库顶部的 **Actions** 标签
2. 你会看到一个正在运行的任务 `iOS Build`
3. 等待约 **15-30分钟**（第一次构建较慢）
4. 构建完成后，点仓库顶部的 **Releases**（在Code页面右侧）
5. 下载 `ETC_Signal_App.ipa` 文件

### 第四步：安装到iPhone

下载到IPA后，用以下任一方式安装：

**方式A：Sideloadly（Windows/Mac都可用，推荐）**
1. 电脑下载 https://sideloadly.io
2. 打开Sideloadly，iPhone用数据线连电脑
3. 把IPA拖进Sideloadly
4. 输入你的Apple ID和密码
5. 点Start，等待安装完成
6. iPhone上：设置 → 通用 → VPN与设备管理 → 信任你的Apple ID
7. 打开APP即可

**注意：** 免费Apple ID签名有效期7天，到期后用Sideloadly重签一次即可（1分钟）。

---

## 备选方案：Codemagic云构建

如果GitHub Actions额度用完，可用Codemagic：

1. 注册 https://codemagic.io
2. 连接你的GitHub仓库
3. 自动识别Flutter项目，点Start new build
4. 构建完成后下载IPA

---

## 常见问题

**Q: 构建失败怎么办？**
A: 点Actions里的失败任务，看红色错误信息，截图发给我。

**Q: 7天到期后APP会怎样？**
A: APP会闪退打不开，重新用Sideloadly签一次就行，数据不会丢。

**Q: 会扣费吗？**
A: GitHub免费账号每月有2000分钟额度，macOS构建一次约扣200分钟，每月能构建约10次，够用。Sideloadly完全免费。

**Q: 必须公开仓库吗？**
A: 免费账号私有仓库也有Actions额度，但公开仓库额度更充足。代码里没有你的私钥，可以公开。
