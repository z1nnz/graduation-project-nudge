import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const serviceAccountPath = path.join(__dirname, '..', 'firebase-service-account.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('\x1b[31m%s\x1b[0m', '【錯誤】找不到金鑰檔案 firebase-service-account.json！');
  console.log('\n請按照以下步驟下載金鑰並放入專案根目錄：');
  console.log('1. 開啟 Firebase Console (https://console.firebase.google.com/)');
  console.log('2. 點擊左上角齒輪「專案設定 (Project settings)」 -> 「服務帳戶 (Service accounts)」');
  console.log('3. 選擇 「Node.js」 並點擊底部的「產生新的私密金鑰 (Generate new private key)」');
  console.log('4. 將下載的 .json 檔案重新命名為 `firebase-service-account.json`，並移至專案根目錄：');
  console.log('   /Users/whzi_111/healthkit/self_discipline_app/firebase-service-account.json\n');
  process.exit(1);
}

// 讀取金鑰並初始化 Admin SDK
const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 預設的使用者 ID
const previewUserId = 'NDG-PREVIEW-USER';
const friendId1 = 'NDG-TEST-FRIEND-1';
const friendId2 = 'NDG-TEST-FRIEND-2';

const mockDailySummaries = [
  {
    date: "2026-05-21",
    completedTasks: 3,
    totalTasks: 5,
    focusMinutes: 45,
    sleepHours: 5.5, // 睡眠不足
    steps: 2800,     // 步數不足
    exerciseMinutes: 10,
    disciplineScore: 62,
    coinsEarned: 10,
    autoTrackedCompleted: 1,
    healthCompleted: 0
  },
  {
    date: "2026-05-22",
    completedTasks: 2,
    totalTasks: 4,
    focusMinutes: 30,
    sleepHours: 6.0,
    steps: 3100,
    exerciseMinutes: 15,
    disciplineScore: 55,
    coinsEarned: 8,
    autoTrackedCompleted: 1,
    healthCompleted: 0
  },
  {
    date: "2026-05-23",
    completedTasks: 5,
    totalTasks: 5,
    focusMinutes: 120, // 專注度高
    sleepHours: 7.5,   // 睡眠充足
    steps: 8200,       // 步數充足
    exerciseMinutes: 30,
    disciplineScore: 95,
    coinsEarned: 30,
    autoTrackedCompleted: 2,
    healthCompleted: 3
  },
  {
    date: "2026-05-24",
    completedTasks: 4,
    totalTasks: 5,
    focusMinutes: 90,
    sleepHours: 7.2,
    steps: 6800,
    exerciseMinutes: 20,
    disciplineScore: 86,
    coinsEarned: 20,
    autoTrackedCompleted: 1,
    healthCompleted: 2
  },
  {
    date: "2026-05-25",
    completedTasks: 3,
    totalTasks: 6,
    focusMinutes: 50,
    sleepHours: 5.8, // 睡眠偏低
    steps: 2900,     // 當日步數少
    exerciseMinutes: 5,
    disciplineScore: 68,
    coinsEarned: 12,
    autoTrackedCompleted: 1,
    healthCompleted: 1
  },
  {
    date: "2026-05-26",
    completedTasks: 4,
    totalTasks: 5,
    focusMinutes: 95,
    sleepHours: 7.8, // 當天充足睡眠與高步數，專注力大幅上升 30%
    steps: 8900,
    exerciseMinutes: 35,
    disciplineScore: 92,
    coinsEarned: 25,
    autoTrackedCompleted: 2,
    healthCompleted: 3
  },
  {
    date: "2026-05-27",
    completedTasks: 3,
    totalTasks: 5,
    focusMinutes: 60,
    sleepHours: 7.0,
    steps: 6500,
    exerciseMinutes: 25,
    disciplineScore: 82,
    coinsEarned: 15,
    autoTrackedCompleted: 1,
    healthCompleted: 2
  }
];

async function seedData() {
  console.log('開始寫入 Firestore 預設數據...');

  // 1. 寫入預設的使用者 Profile
  const userRef = db.collection('users').doc(previewUserId);
  await userRef.set({
    nickname: '自律先行者 (Preview User)',
    signature: '追求更好的自律生活，AI 智慧行星成長中！',
    myNudgeId: 'NDG-PREVIEW-USER',
    username: 'NDG-PREVIEW-USER',
    themeMode: 'dark',
    accentColor: 4286287350, // const Color(0xFF7C6AE6)
    disciplineCoins: 120,
    avatarProfile: {
      gender: 'male',
      hairStyle: 'short',
      hairColor: 'brown',
      eyeStyle: 'normal',
      eyeColor: 'blue',
      skinColor: 'light',
      clothesStyle: 'jacket',
      clothesColor: 'purple',
      backGroundColor: 'gradient_dark',
      faceAccessory: 'glasses',
      hatStyle: 'none'
    },
    unlockedAvatarItems: ['item_glasses_01', 'item_jacket_purple'],
    tasks: [
      { id: 't_01', title: '每日閱讀 30 分鐘', done: true, priority: 'medium', rewardCoins: 10, sourceType: 'custom' },
      { id: 't_02', title: '喝水 2000ml', done: true, priority: 'low', rewardCoins: 5, sourceType: 'custom' },
      { id: 't_03', title: '散步步數達標 6000 步', done: false, priority: 'high', rewardCoins: 15, sourceType: 'steps' }
    ],
    dailySummaries: mockDailySummaries,
    unlockedBadgeDates: {
      'task_starter': '2026-05-23',
      'streak_hero': '2026-05-24'
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('✔ 已寫入主測試帳號 (NDG-PREVIEW-USER)');

  // 2. 寫入好友帳號 1
  const friendRef1 = db.collection('users').doc(friendId1);
  await friendRef1.set({
    nickname: '阿信 (自律隊友)',
    signature: '晨跑與讀書是我熱愛的自律日常。',
    myNudgeId: 'NDG-FRIEND-ASHIN',
    username: 'NDG-FRIEND-ASHIN',
    disciplineCoins: 250,
    avatarProfile: {
      gender: 'male',
      hairStyle: 'curly',
      hairColor: 'black',
      eyeStyle: 'normal',
      eyeColor: 'black',
      skinColor: 'tan',
      clothesStyle: 'hoodie',
      clothesColor: 'green',
      backGroundColor: 'gradient_teal',
      faceAccessory: 'none',
      hatStyle: 'none'
    },
    focusSeconds: 7200, // 今日已專注 2 小時
    isStudying: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('✔ 已寫入好友 1 (NDG-FRIEND-ASHIN)');

  // 3. 寫入好友帳號 2
  const friendRef2 = db.collection('users').doc(friendId2);
  await friendRef2.set({
    nickname: '小梅 (冥想少女)',
    signature: '今天也是寧靜專注的一天。',
    myNudgeId: 'NDG-FRIEND-MAY',
    username: 'NDG-FRIEND-MAY',
    disciplineCoins: 80,
    avatarProfile: {
      gender: 'female',
      hairStyle: 'long',
      hairColor: 'gold',
      eyeStyle: 'sleepy',
      eyeColor: 'brown',
      skinColor: 'fair',
      clothesStyle: 'dress',
      clothesColor: 'pink',
      backGroundColor: 'gradient_pink',
      faceAccessory: 'none',
      hatStyle: 'beret'
    },
    focusSeconds: 1800, // 今日專注 30 分鐘
    isStudying: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  console.log('✔ 已寫入好友 2 (NDG-FRIEND-MAY)');

  // 4. 將好友關係加入主帳號的子集合中
  const userFriend1Ref = db.collection('users').doc(previewUserId).collection('friends').doc(friendId1);
  await userFriend1Ref.set({
    id: friendId1,
    nudgeId: 'NDG-FRIEND-ASHIN',
    name: '阿信 (自律隊友)',
    signature: '晨跑與讀書是我熱愛的自律日常。',
    todayFocusSeconds: 7200,
    isStudying: true
  });
  console.log('✔ 已建立測試好友關係 (阿信)');

  // 5. 寫入三個預設自律房間 (Study Rooms)
  const room1Ref = db.collection('rooms').doc('room_01');
  await room1Ref.set({
    id: 'room_01',
    name: '☕ 深夜極簡專注自修室',
    description: '安靜專注不說話，歡迎晚上 9 點到凌晨 2 點的夜貓子加入。',
    accentColor: 4286287350, // 0xFF7C6AE6
    members: [
      {
        memberId: 'NDG-FRIEND-ASHIN',
        name: '阿信 (自律隊友)',
        roomNickname: '阿信',
        status: 'studying',
        sessionSeconds: 3600,
        todayFocusSeconds: 7200,
        todayMetricValue: 2.0,
        avatarColor: 4282361730,
        role: 'member',
        personalGoalSeconds: 7200,
        hasReachedPersonalGoal: true,
        isApproved: true
      },
      {
        memberId: 'NDG-FRIEND-MAY',
        name: '小梅 (冥想少女)',
        roomNickname: '小梅',
        status: 'resting',
        sessionSeconds: 0,
        todayFocusSeconds: 1800,
        todayMetricValue: 0.5,
        avatarColor: 4293939634,
        role: 'member',
        personalGoalSeconds: 3600,
        hasReachedPersonalGoal: false,
        isApproved: true
      }
    ],
    ownerId: 'NDG-FRIEND-ASHIN',
    ownerName: '阿信',
    announcement: '請保持安靜，每晚 10:00 點將進行半小時集體番茄鐘！',
    tags: ['專注', '夜貓子', '靜音'],
    memberLimit: 8,
    category: '讀書專注',
    dailyGoalHours: 2,
    roomType: 'study',
    goalSourceType: 'studyRoom',
    dailyGoalValue: 2.0,
    goalUnitLabel: '小時',
    joinMode: 'instant',
    joinQuestionsEnabled: false,
    joinQuestions: [],
    nicknameRuleEnabled: false,
    nicknameRuleText: '',
    roomRules: '1. 保持安靜\n2. 勿發布廣告',
    password: '',
    challengeTitle: '深夜番茄鐘拉力賽',
    challengeDescription: '累計專注時間滿 3 小時即可達標！',
    challengeGoalSeconds: 10800,
    challengeDeadlineLabel: '今天 23:59',
    challengeCompleted: false,
    syncTaskEnabled: true,
    dailyRecords: [],
    messages: [
      { id: 'm1', senderId: 'NDG-FRIEND-ASHIN', senderName: '阿信', text: '大家好！今天也要加油專注！', type: 'text', createdAt: new Date().toISOString() }
    ],
    events: [
      { id: 'ev1', actorId: 'NDG-FRIEND-ASHIN', actorName: '阿信', text: '阿信加入了房間。', type: 'join', createdAt: new Date().toISOString() }
    ]
  });

  const room2Ref = db.collection('rooms').doc('room_02');
  await room2Ref.set({
    id: 'room_02',
    name: '🏃‍♂️ 每日健康晨跑俱樂部',
    description: '晨起散步或晨跑，累積每日前 3000 步的健康起點！',
    accentColor: 4280549747, // 0xFF10B981
    members: [
      {
        memberId: 'NDG-FRIEND-ASHIN',
        name: '阿信 (自律隊友)',
        roomNickname: '阿信',
        status: 'studying',
        sessionSeconds: 1800,
        todayFocusSeconds: 1800,
        todayMetricValue: 4500, // 4500 步
        avatarColor: 4282361730,
        role: 'owner',
        personalGoalSeconds: 6000,
        hasReachedPersonalGoal: false,
        isApproved: true
      }
    ],
    ownerId: 'NDG-FRIEND-ASHIN',
    ownerName: '阿信',
    announcement: '早晨 6 點到 8 點之間一起走路健康同步！',
    tags: ['健康', '運動', '散步'],
    memberLimit: 12,
    category: '健康運動',
    dailyGoalHours: 1,
    roomType: 'steps',
    goalSourceType: 'steps',
    dailyGoalValue: 6000.0,
    goalUnitLabel: '步',
    joinMode: 'instant',
    joinQuestionsEnabled: false,
    joinQuestions: [],
    nicknameRuleEnabled: false,
    nicknameRuleText: '',
    roomRules: '保持清晨運動習慣！',
    password: '',
    challengeTitle: '清晨萬步挑戰',
    challengeDescription: '單日走路滿 8000 步',
    challengeGoalSeconds: 8000,
    challengeDeadlineLabel: '今天 12:00',
    challengeCompleted: false,
    syncTaskEnabled: false,
    dailyRecords: [],
    messages: [],
    events: []
  });

  const room3Ref = db.collection('rooms').doc('room_03');
  await room3Ref.set({
    id: 'room_03',
    name: '💤 規律作息早睡早起星人',
    description: '監督早睡！目標每晚 11 點前躺平，爭取睡滿 7.5 小時。',
    accentColor: 4281313493, // 0xFF1E293B
    members: [
      {
        memberId: 'NDG-FRIEND-MAY',
        name: '小梅 (冥想少女)',
        roomNickname: '小梅',
        status: 'offline',
        sessionSeconds: 0,
        todayFocusSeconds: 0,
        todayMetricValue: 8.0, // 8.0 小時睡眠
        avatarColor: 4293939634,
        role: 'owner',
        personalGoalSeconds: 7.5 * 3600,
        hasReachedPersonalGoal: true,
        isApproved: true
      }
    ],
    ownerId: 'NDG-FRIEND-MAY',
    ownerName: '小梅',
    announcement: '11 點前關燈鎖機！',
    tags: ['作息', '睡眠', '早起'],
    memberLimit: 15,
    category: '規律睡眠',
    dailyGoalHours: 8,
    roomType: 'sleep',
    goalSourceType: 'sleepHours',
    dailyGoalValue: 7.5,
    goalUnitLabel: '小時',
    joinMode: 'instant',
    joinQuestionsEnabled: false,
    joinQuestions: [],
    nicknameRuleEnabled: false,
    nicknameRuleText: '',
    roomRules: '早睡早起身體好！',
    password: '',
    challengeTitle: '關燈大挑戰',
    challengeDescription: '23:00 前躺平並記錄睡眠',
    challengeGoalSeconds: 7.5 * 3600,
    challengeDeadlineLabel: '明天 07:00',
    challengeCompleted: false,
    syncTaskEnabled: false,
    dailyRecords: [],
    messages: [],
    events: []
  });
  console.log('✔ 已成功寫入三個預設自律房間 (room_01, room_02, room_03)');

  console.log('\n\x1b[32m%s\x1b[0m', '🎉 資料庫初始化與測試數據寫入成功！');
  process.exit(0);
}

seedData().catch((err) => {
  console.error('\x1b[31m%s\x1b[0m', '寫入時發生錯誤：', err);
  process.exit(1);
});
