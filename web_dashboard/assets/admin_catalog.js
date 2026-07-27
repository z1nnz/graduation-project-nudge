(function attachAdminCatalog(root, factory) {
  const api = factory();

  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }

  root.NudgeAdminCatalog = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function createAdminCatalog() {
  const DEFAULT_REQUIREMENTS = [
    { level: 1, experience: 0 },
    { level: 30, experience: 10000 },
    { level: 60, experience: 30000 },
  ];

  function text(value) {
    return String(value == null ? '' : value).trim();
  }

  function number(value, fallback) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function validateAvatarSeriesDraft(draft) {
    const errors = [];
    const source = draft || {};
    const stages = Array.isArray(source.stages) ? source.stages : [];
    const seriesName = text(source.seriesName || source.name);
    const seriesKey = text(source.seriesKey);
    const codexDescription = text(source.codexDescription);
    const price = number(source.price, NaN);

    if (!seriesName) errors.push('請輸入角色系列名稱');
    if (!codexDescription) errors.push('請輸入系列圖鑑介紹');
    if (!/^[a-z0-9][a-z0-9_-]*$/i.test(seriesKey)) {
      errors.push('系列代碼只能使用英數、底線與連字號');
    }
    if (!Number.isFinite(price) || price < 0) {
      errors.push('商城價格必須是大於或等於 0 的數字');
    }
    if (stages.length !== 3) {
      errors.push('完整進化鏈必須剛好包含 3 階角色');
    }

    let previousLevel = -1;
    let previousExperience = -1;
    stages.forEach((stage, index) => {
      const stageNumber = index + 1;
      const requirement = DEFAULT_REQUIREMENTS[index];
      const level = number(stage.requiredLevel, requirement.level);
      const experience = number(stage.requiredExperience, requirement.experience);

      if (!text(stage.name)) errors.push(`第 ${stageNumber} 階缺少角色名稱`);
      if (!text(stage.description)) errors.push(`第 ${stageNumber} 階缺少圖鑑描述`);
      if (!text(stage.characterAsset)) errors.push(`第 ${stageNumber} 階缺少角色圖片`);
      if (!text(stage.iconAsset)) errors.push(`第 ${stageNumber} 階缺少角色圖示`);
      if (!Number.isInteger(level) || level < 1) {
        errors.push(`第 ${stageNumber} 階所需等級必須是正整數`);
      }
      if (!Number.isInteger(experience) || experience < 0) {
        errors.push(`第 ${stageNumber} 階所需經驗值必須是非負整數`);
      }
      if (index === 0 && (level !== 1 || experience !== 0)) {
        errors.push('初始角色必須從等級 1、經驗值 0 開始');
      }
      if (index > 0 && (level <= previousLevel || experience <= previousExperience)) {
        errors.push(`第 ${stageNumber} 階的等級與經驗值必須嚴格遞增`);
      }

      previousLevel = level;
      previousExperience = experience;
    });

    return errors;
  }

  function buildAvatarSeriesPayload(draft) {
    const errors = validateAvatarSeriesDraft(draft);
    if (errors.length) {
      throw new Error(errors.join('\n'));
    }

    const source = draft || {};
    const seriesName = text(source.seriesName || source.name);
    const seriesKey = text(source.seriesKey).toLowerCase();
    const theme = text(source.theme);
    const codexDescription = text(source.codexDescription || source.description);
    const baseIndex = Math.trunc(number(source.catalogIndexBase, 1000));
    const price = Math.trunc(number(source.price, 0));
    const stages = source.stages.map((stage, index) => {
      const stageNumber = index + 1;
      const requirement = DEFAULT_REQUIREMENTS[index];

      return {
        stage: stageNumber,
        catalog_index: baseIndex + index,
        name: text(stage.name),
        description: text(stage.description),
        character_asset: text(stage.characterAsset),
        icon_asset: text(stage.iconAsset),
        required_level: Math.trunc(number(stage.requiredLevel, requirement.level)),
        required_experience: Math.trunc(
          number(stage.requiredExperience, requirement.experience),
        ),
        shop_eligible: stageNumber === 1,
        coin_price: stageNumber === 1 ? price : 0,
        evolves_from_stage: stageNumber === 1 ? null : stageNumber - 1,
      };
    });

    return {
      schema_version: 1,
      type: 'avatar_series',
      status: text(source.status) || 'published',
      name: seriesName,
      description: codexDescription,
      price,
      series_key: seriesKey,
      series_name: seriesName,
      series_theme: theme,
      theme,
      codex_description: codexDescription,
      series: {
        key: seriesKey,
        name: seriesName,
        theme,
        codex_description: codexDescription,
      },
      catalog_index_base: baseIndex,
      image_path: stages[0].character_asset,
      icon_path: stages[0].icon_asset,
      character_stages: stages,
      start_at: source.startAt || null,
      end_at: source.endAt || null,
      expires_at: source.expiresAt || null,
      created_by: text(source.createdBy),
      created_at: source.createdAt || null,
      updated_at: source.updatedAt || null,
    };
  }

  return {
    DEFAULT_REQUIREMENTS,
    validateAvatarSeriesDraft,
    buildAvatarSeriesPayload,
  };
});
