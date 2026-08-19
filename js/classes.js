/* Gloamrift · class presentation for the creation hall */
window.GLOAM_CLASSES = {
  warrior: {
    id: "warrior",
    glyph: "⚔",
    en: "Ashen Warden",
    zh: "战士",
    role: "Melee · Fortitude",
    roleZh: "近战 · 坚韧",
    desc: "Close steel and stubborn blood. Highest weapon damage — poorest at being kited.",
    descZh: "近身缠斗，靠护甲和生命硬吃伤害。武器伤害最高，怕被风筝。",
    lore: "石桥镇的守夜人把裂隙当成一种天气。战士把裂隙当成一种工作。",
    info: "高 力量 / 体魄",
    base: { str: 22, dex: 12, vit: 22, ene: 8 },
    accent: "#c45a3a"
  },
  mage: {
    id: "mage",
    glyph: "✧",
    en: "Rift Scholar",
    zh: "法师",
    role: "Ranged · Arcana",
    roleZh: "远程法术 · 范围控场",
    desc: "The rift answers those who ask in the old tongue. Blood is thin. Footwork is everything.",
    descZh: "远程法术输出，范围伤害与控制最强。血少，站位一错就没。",
    lore: "执政官禁止私探裂隙。禁令只对不会读符文的人生效。",
    info: "高 精神",
    base: { str: 9, dex: 12, vit: 12, ene: 24 },
    accent: "#6a8ad8"
  },
  archer: {
    id: "archer",
    glyph: "➶",
    en: "Eastwatch Ranger",
    zh: "弓箭手",
    role: "Ranged · Precision",
    roleZh: "远程物理 · 高攻速",
    desc: "Longest reach, swiftest hands. Burst lives on the crit. Never let them close.",
    descZh: "射程最远、攻速最快，靠位移拉开距离。单体爆发依赖暴击。",
    lore: "入夜后没人往东边看。弓箭手是少数仍在看的人。",
    info: "高 敏捷",
    base: { str: 12, dex: 24, vit: 14, ene: 12 },
    accent: "#6a8a44"
  }
};

window.GLOAM_NAMES = [
  "Aldric", "Vesper", "Cael", "Thorn", "Isolde", "Rowan", "Maelis", "Sable",
  "Idris", "Nyx", "Corvin", "Elara", "Riven", "Kael", "Oren", "Lyra", "Bram",
  "Ysolde", "Dorian", "Ashen", "Mireille", "Torin", "Wren", "Liora", "Cairn",
  "Serin", "Vale", "Morrow", "Quill", "Hester"
];
