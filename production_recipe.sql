WITH
/* ОТБИРАЕМ НУЖНУЮ ВЕРСИЮ */
selected_version AS (
    SELECT
        version_id,
		version_name
    FROM
        sb_dm_scmai.versions
    WHERE
        version_type ILIKE '%ППР%'
        AND date_from = DATE '2026-02-01'
    ORDER BY
        version_id DESC
    LIMIT 1
)
/* ТЕКСТЫ ОРГАНИЗАЦИЙ */
, organizations as (
	SELECT
		organization_code,
		organization_name_ru,
		organization_short_name_ru
	FROM
		SB_DM_SCMAI.ORGANIZATIONS
)
/* ТЕКСТЫ УСТАНОВОК */
, units as (
	SELECT
		id,
		code,
		name
	FROM
		SB_DM_SCMAI.UNITS
)
/* ТЕКСТЫ МАТЕРИАЛОВ */
, materials as (
	SELECT
		dpo_code,
		dpo_short_name,
		dpo_name,
		mtr_code,
		mtr_prod_head_1_name,
		mtr_prod_head_2_name,
		mtr_prod_head_3_name,
		mtr_prod_head_4_name,
		mtr_prod_head_5_name,
		mtr_prod_head_6_name,
		mtr_name
	FROM
		SB_DM_SCMAI.MATERIALS
)
/* СВЯЗЬ УСТАНОВОК И ВЕРСИИ. ОТБИРАЕМ НУЖНЫЕ УСТАНОВКИ ПО ВЕРСИИ */
, actual_units as (
	SELECT
		v.version_id,
		u.code as unit_code,
		u.name as unit_name
	FROM
		SB_DM_SCMAI.UNIT_VERSIONS as uv
	INNER JOIN selected_version as v
		ON uv.version_id = v.version_id
	INNER JOIN units as u
		ON uv.unit_id = u.id
)
/* УРОВЕНЬ ПРОИЗВОДСТВЕННЫХ УСТАНОВОК */
, production_unit as (
	SELECT
		'УСТАНОВКА' as production_level,
		pu.version_id,
		pu.cal_month,
		pu.plant_code,
		o.organization_name_ru as plant_name,
		o.organization_short_name_ru as plant_short_name,
		COALESCE(pu.mode_group_code, '') as mode_group_code,
		COALESCE(pu.mode_group_name, '') as mode_group_name,
		pu.unit_code,
		u.unit_name,
		pu.volume, -- Нужно убрать комментарии, чтобы модель больше не смотрела сюда
		pu.unit_capacity_min,
		pu.unit_capacity_max,
		COALESCE(pu.loaded_capacity, 0) as loaded_capacity, -- Целевой атрибут для анализа
		pu.business_unit_name,
		pu.unit_business_unit_name
	FROM
		SB_DM_SCMAI.PRODUCTION_UNITS as pu
	INNER JOIN selected_version as v
		ON pu.version_id = v.version_id
	LEFT JOIN organizations as o
		ON pu.plant_code = o.organization_code
	LEFT JOIN actual_units as u
		ON pu.unit_code = u.unit_code
)
/* УРОВЕНЬ ПРОИЗВОДСТВЕННЫХ РЕЖИМОВ. ДЕТАЛИЗАЦИЯ УСТАНОВОК */
, production_mode as (
	SELECT
		'РЕЖИМ' as production_level,
		pm.version_id,
		pm.cal_month,
		pm.plant_code,
		pu.plant_name,
		pu.plant_short_name,
		pm.unit_code,
		pu.unit_name,
		pu.mode_group_code,
		pu.mode_group_name,
		pm.mode_code,
		pm.mode_name,
		COALESCE(pm.mode_production_volume, 0) as mode_production_volume,
		COALESCE(pm.mode_capacity_min, 0) as mode_capacity_min,
		COALESCE(pm.mode_capacity_max, 0) as mode_capacity_max,
		COALESCE(pm.performance_factor, 0) as performance_factor,
		COALESCE(pm.cost, 0) as cost,
		COALESCE(pm.total, 0) as total,
		COALESCE(pm.loaded_capacity, 0) as loaded_capacity-- Вроде как тоже не целевой атрибут
	FROM
		SB_DM_SCMAI.PRODUCTION_MODES as pm
	INNER JOIN production_unit as pu
		ON pm.version_id = pu.version_id
		AND pm.cal_month = pu.cal_month
		AND pm.plant_code = pu.plant_code
		AND pm.unit_code = pu.unit_code
)
, production_recipe as (
	SELECT
		'РЕЦЕПТ' as production_level,
		pr.version_id,
		pr.cal_month,
		pm.plant_name,
		pr.unit_code,
		pm.unit_name,
		pm.mode_group_code,
		pm.mode_group_name,
		pr.mode_code,
		pm.mode_name,
		pr.recipe_material_type,
		pr.dpo_code,
		m.dpo_name,
		m.dpo_short_name,
		m.mtr_prod_head_1_name,
		m.mtr_prod_head_2_name,
		m.mtr_prod_head_3_name,
		m.mtr_prod_head_4_name,
		m.mtr_prod_head_5_name,
		m.mtr_prod_head_6_name,
		pr.base_uom,
		pr.semiproduct_flg,
		COALESCE(pr.material_volume, 0) as material_volume,
		COALESCE(pr.material_rate, 0) as material_rate,
		COALESCE(pr.loaded_capacity, 0) as loaded_capacity -- Вроде как тоже не целевой
	FROM
		SB_DM_SCMAI.PRODUCTION_RECIPE as pr
	INNER JOIN production_mode as pm
		ON pr.version_id = pm.version_id
		AND pr.cal_month = pm.cal_month
		AND pr.unit_code = pm.unit_code
		AND pr.mode_code = pm.mode_code
	LEFT JOIN materials as m
		ON m.dpo_code = pr.dpo_code
)
SELECT
	'РЕЦЕПТ' as production_level,
	version_id,
	cal_month,
	plant_name,
	unit_code,
	unit_name,
	mode_group_code,
	mode_group_name,
	mode_code,
	mode_name,
	recipe_material_type,
	dpo_code,
	dpo_name,
	dpo_short_name,
	mtr_prod_head_1_name,
	mtr_prod_head_2_name,
	mtr_prod_head_3_name,
	mtr_prod_head_4_name,
	mtr_prod_head_5_name,
	mtr_prod_head_6_name,
	base_uom,
	semiproduct_flg,
	material_volume,
	material_rate
FROM
	production_recipe;