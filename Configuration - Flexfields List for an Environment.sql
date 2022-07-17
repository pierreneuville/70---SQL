SELECT descriptive_flexfield_code, name
, context_code
, segment_code
, segment_identifier
, required_flag
, data_type
, table_name
, COLUMN_NAME
, VALUE_SET_CODE
, LAST_UPDATED_BY
, LAST_UPDATE_DATE
, DEPLOYMENT_STATUS
FROM (SELECT dfd.descriptive_flexfield_code
, dfc.context_code
, dfs.segment_code
, dfs.required_flag
, dfs.segment_identifier
, vsd.value_data_type data_type
, vsd.VALUE_SET_CODE
, dfs.LAST_UPDATED_BY
, dfs.LAST_UPDATE_DATE
, dft.table_name
, dfs.COLUMN_NAME
, dfd.DEPLOYMENT_STATUS
, dfd.name
FROM fusion.FND_DF_FLEXFIELDS_VL dfd
, fusion.fnd_df_contexts_b dfc
, fusion.fnd_df_segments_b dfs
, fusion.fnd_vs_value_sets vsd
, fusion.fnd_df_flex_usages_b dfu
, fusion.fnd_df_table_usages dft
WHERE dfd.flexfield_type = 'DFF'
AND dfd.descriptive_flexfield_code = dfc.descriptive_flexfield_code (+)
AND dfd.application_id = dfc.application_id (+)
AND dfc.enabled_flag (+) = 'Y'
AND dfs.descriptive_flexfield_code (+) = dfc.descriptive_flexfield_code
AND dfs.application_id (+) = dfc.application_id
AND dfs.context_code (+) = dfc.context_code
AND dfc.context_code IS NOT NULL
AND dfs.enabled_flag (+) = 'Y'
AND dfs.read_only_flag (+) = 'N'
AND vsd.value_set_id (+) = dfs.value_set_id
AND dfu.application_id = dfd.application_id
AND dfu.descriptive_flexfield_code = dfd.descriptive_flexfield_code
AND dfu.usage_type = 'D'
AND dft.application_id = dfu.application_id
AND dft.descriptive_flexfield_code = dfu.descriptive_flexfield_code
AND dft.flexfield_usage_code = dfu.flexfield_usage_code
AND dft.table_type = 'BASE'
UNION ALL
SELECT dfd.descriptive_flexfield_code
, 'Global Data Elements' context_code ,dfs.segment_code
, dfs.required_flag
, dfs.segment_identifier
, vsd.value_data_type data_type
, vsd.VALUE_SET_CODE
, dfs.LAST_UPDATED_BY
, dfs.LAST_UPDATE_DATE
, dft.table_name
, dfs.COLUMN_NAME
, dfd.DEPLOYMENT_STATUS
, dfd.name
FROM fusion.FND_DF_FLEXFIELDS_VL dfd
, fusion.fnd_df_segments_b dfs
, fusion.fnd_vs_value_sets vsd
, fusion.fnd_df_flex_usages_b dfu
, fusion.fnd_df_table_usages dft
WHERE dfd.flexfield_type = 'DFF'
AND dfs.descriptive_flexfield_code = dfd.descriptive_flexfield_code
AND dfs.application_id = dfd.application_id
AND dfs.context_code = 'Global Data Elements'
AND dfs.enabled_flag = 'Y'
AND dfs.read_only_flag = 'N'
AND vsd.value_set_id = dfs.value_set_id
AND dfu.application_id = dfd.application_id
AND dfu.descriptive_flexfield_code = dfd.descriptive_flexfield_code
AND dfu.usage_type = 'D'
AND dft.application_id = dfu.application_id
AND dft.descriptive_flexfield_code = dfu.descriptive_flexfield_code
AND dft.flexfield_usage_code = dfu.flexfield_usage_code
AND dft.table_type = 'BASE') dff
--where dff.descriptive_flexfield_code = 'PER_PERSONS_DFF'
ORDER BY dff.descriptive_flexfield_code
, dff.context_code