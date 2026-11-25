(function () {
  'use strict';
  // Showcase for slice J1: every catalog character, its animations and its
  // speech box. Not linked from the town; for checking the art.
  const players = window.NudgeSpritePlayer;
  const stage = document.getElementById('cdStage');
  const LINES = {
    companion: ['今天也一起努力吧！', '點小鎮裡的建築，我們去看看那裡能做什麼。'],
    chestnut: ['歡迎光臨栗子雜貨店！', '貨架上的衣服和家具，都可以拿起來看看。'],
    scroll: ['我是告示員阿紙。', '板子上的委託單做完就能拿金幣和經驗喔。'],
    bounce: ['嘿嘿，休息時間到了嗎？', '專注滿 25 分鐘，就來售票亭換一張休息券！'],
    sprout: ['花園的植物都是你的努力長出來的。', '點一株植物，看看它是哪一天種下的。'],
    inky: ['圖書館請保持安靜。', '你的成長紀錄，都整理在這些書架上。'],
    bell: ['塔門開著，燈也點好了。', '想專心的時候，就上樓來吧。'],
    letty: ['有你的信！', '朋友寄來的鼓勵，我都會送到信箱。'],
    stella: ['今晚的星星很亮呢。', '用望遠鏡看看，你這週走了多遠。'],
  };
  const sprites = [];
  for (const c of players.CATALOG.characters) {
    const li = document.createElement('li');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'cd-npc';
    btn.setAttribute('aria-label', `和${c.name}說話（${c.role}）`);
    const el = document.createElement('span');
    const name = document.createElement('span');
    name.textContent = c.name;
    const role = document.createElement('small');
    role.textContent = c.role;
    btn.append(el, name, role);
    li.appendChild(btn);
    stage.appendChild(li);
    const sprite = players.characterPlayer(el, c.id, { size: 128 });
    sprites.push(sprite);
    btn.addEventListener('click', () => {
      window.NudgeNpcDialog.open({ speaker: c.id, lines: LINES[c.id] });
    });
  }
  for (const b of document.querySelectorAll('[data-anim]')) {
    b.addEventListener('click', () => {
      for (const s of sprites) {
        const anim = b.dataset.anim;
        const loopBack = () => s.play('idle');
        s.play(anim, { onEnd: loopBack });
      }
    });
  }
})();
