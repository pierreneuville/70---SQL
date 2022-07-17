SELECT To_char("ff_formulas_vl"."effective_start_date", 'DD-MON-YYYY') AS
       "EFFECTIVE_START_DATE",
       To_char("ff_formulas_vl"."effective_end_date", 'DD-MON-YYYY')   AS
       "EFFECTIVE_END_DATE",
       "ff_formulas_vl"."base_formula_name"                            AS
       "BASE_FORMULA_NAME",
       "ff_formulas_vl"."formula_name"                                 AS
       "FORMULA_NAME",
       "ff_formulas_vl"."description"                                  AS
       "DESCRIPTION",
       "ff_formulas_vl"."edit_status"                                  AS
       "EDIT_STATUS",
       "ff_formulas_vl"."formula_text"                                 AS
       "FORMULA_TEXT",
       "ff_formulas_vl"."compile_flag"                                 AS
       "COMPILE_FLAG",
       "ff_formulas_vl"."legislation_code"                             AS
       "LEGISLATION_CODE",
       To_char("ff_formulas_vl"."last_update_date", 'DD-MON-YYYY')     AS
       "LAST_UPDATE_DATE",
       "ff_formulas_vl"."last_updated_by"                              AS
       "LAST_UPDATED_BY",
       "ff_formulas_vl"."created_by"                                   AS
       "CREATED_BY",
       To_char("ff_formulas_vl"."creation_date", 'DD-MON-YYYY')        AS
       "CREATION_DATE",
       "ff_formula_types_tl"."formula_type_name"                       AS
       "FORMULA_TYPE_NAME"
FROM   "FUSION"."ff_formula_types_tl" "FF_FORMULA_TYPES_TL",
       "FUSION"."ff_formulas_vl" "FF_FORMULAS_VL"
WHERE  "ff_formulas_vl"."formula_type_id" =
       "ff_formula_types_tl"."formula_type_id" 