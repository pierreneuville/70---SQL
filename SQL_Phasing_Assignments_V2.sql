with my_plan_date as(					
select 	cmp_plan.plan_id, 
		cpm_lang.plan_name, 
		cmp_period.period_name,
		cmp_period.start_date,
		cmp_period.end_date,
		cmp_period.freeze_date 
from cmp_plans_b cmp_plan
inner join cmp_plan_periods cmp_period on cmp_plan.plan_id = cmp_period.plan_id
inner join cmp_plans_tl cpm_lang on cmp_plan.plan_id = cpm_lang.plan_id and cpm_lang.LANGUAGE = 'US' /*param*/
where 1=1
and plan_name ='CASA - Campagne Salariale (PNE)' /*param*/
and period_name='CASAES - 2022' /*param*/
order by 1),


emp_profiles as (
	select 
		paf.person_id
		,CASE
			WHEN HPI.ATTRIBUTE_DATE2>=HPI.ATTRIBUTE_DATE1 AND HPI.ATTRIBUTE_DATE2<=freeze_date THEN HPI.ATTRIBUTE2
			WHEN HPI.ATTRIBUTE_DATE1>HPI.ATTRIBUTE_DATE2 AND HPI.ATTRIBUTE_DATE2<=freeze_date THEN HPI.ATTRIBUTE2
			WHEN HPI.ATTRIBUTE_DATE1 is null and HPI.ATTRIBUTE_DATE2<=freeze_date THEN HPI.ATTRIBUTE2
			WHEN HPI.ATTRIBUTE_DATE2 is null and HPI.ATTRIBUTE_DATE1<=freeze_date THEN HPI.ATTRIBUTE1 
		END "SITUATION"
		,CASE
			WHEN HPI.ATTRIBUTE_DATE2>=HPI.ATTRIBUTE_DATE1 AND HPI.ATTRIBUTE_DATE2<=freeze_date THEN HPI.ATTRIBUTE_DATE2
			WHEN HPI.ATTRIBUTE_DATE1>HPI.ATTRIBUTE_DATE2 AND HPI.ATTRIBUTE_DATE2<=freeze_date THEN HPI.ATTRIBUTE_DATE2
			WHEN HPI.ATTRIBUTE_DATE1 is null and HPI.ATTRIBUTE_DATE2<=freeze_date THEN HPI.ATTRIBUTE_DATE2
			WHEN HPI.ATTRIBUTE_DATE2 is null and HPI.ATTRIBUTE_DATE1<=freeze_date THEN HPI.ATTRIBUTE_DATE1 
		END "EMP_EFFECTIVE_START_DATE"
	FROM
	HRT_PROFILES_B HPB,
	HRT_PROFILE_ITEMS HPI,
	HRT_CONTENT_TYPES_TL CT,
	per_all_people_f paf,
	my_plan_date pld
	WHERE 1=1
	and paf.person_id= HPB.person_id
	and HPB.PROFILE_ID=HPI.PROFILE_ID
	and HPI.CONTENT_TYPE_ID=CT.CONTENT_TYPE_ID
	and CT.language='F' /*param*/
	and HPI.SECTION_ID='300000003197644' /*param à vérifier lors de la migration d'environnements*/
	and paf.person_number like (:Person_number_param) /*param*/
	and ((HPI.ATTRIBUTE_DATE2 is not null) or (HPI.ATTRIBUTE_DATE1 is not null))
	and ((HPI.ATTRIBUTE2 is not null) or (HPI.ATTRIBUTE1 is not null))
),

my_assignments as (
select 				'ASSIGNMENT'
				   ,paf.person_number
				   ,paf.person_id
				   ,ppn.last_name
				   ,ppn.first_name
				   ,paa.effective_start_date
				   --,FIRST_VALUE(paa.effective_start_date) OVER (PARTITION BY paf.person_id,fabu.bu_name,PAMMF.Value,pd.name, paa.ASSIGNMENT_STATUS_TYPE ORDER BY paf.person_id, paa.effective_start_date) AS first_eff_date
				   ,paa.effective_end_date
				   ,fabu.bu_name
				   ,PAMMF.Value	"FTE"
				   ,pd.name as department_name
				   ,lookup_contract.meaning "CONTRACT"
				   ,epp.situation as C1_C2_DIR
				   ,epp_freeze.situation as C1_C2_DIR_FREEZE
				   ,paa.reason_code
				   ,sal.SALARY_AMOUNT
				   ,pps.actual_termination_date
				   --,'ASSIGNMENT' as ASS_TYPE
		from PER_ALL_PEOPLE_F paf
		inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and assignment_type='E' --and ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
		inner join per_periods_of_service pps on paa.person_id = pps.person_id and paa.period_of_service_id = pps.period_of_service_id
		left join my_plan_date pld on 1=1
		left join emp_profiles epp on epp.person_id =paf.person_id and epp.EMP_EFFECTIVE_START_DATE<=paa.effective_start_date
		left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date
		left join PER_CONTRACTS_F pcf on pcf.person_id=paa.person_id and pcf.contract_id=paa.contract_id
			left join FND_LOOKUP_VALUES_TL lookup_contract on pcf.type = lookup_contract.lookup_code and lookup_contract.lookup_type = 'CONTRACT_TYPE' and lookup_contract.language = 'F' /*Param*/
		left join CMP_SALARY sal on sal.person_id = paa.person_id and sal.assignment_id=paa.assignment_id and sal.date_from<=paa.effective_start_date --between  and sal.date_to
		left join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
		left join per_departments pd on paa.organization_id = pd.organization_id
		left join FUN_ALL_BUSINESS_UNITS_V fabu on paa.BUSINESS_UNIT_ID = fabu.BU_ID
		left join PER_ASSIGN_WORK_MEASURES_F PAMMF on paa.assignment_id = PAMMF.assignment_id and PAMMF.unit = 'FTE' and paa.effective_start_date between PAMMF.effective_start_date and PAMMF.effective_end_date
		left join HR_LOCATIONS_ALL hla on paa.location_id = hla.location_id
		where 1=1 
		and pld.freeze_date between ppn.effective_start_date and ppn.effective_end_date
		and pld.freeze_date between pd.effective_start_date and pd.effective_end_date
		and pld.freeze_date between paf.effective_start_date and paf.effective_end_date
		and pld.freeze_date between pcf.effective_start_date and pcf.effective_end_date
		and paf.person_number like (:Person_number_param) /*param*/
		/*and fabu.bu_name = 'CASA ES' param*/
),

my_assignments_profile as
(
	select 			   'PROFILE'
					   ,paf.person_number
					   ,paf.person_id
					   ,ppn.last_name
					   ,ppn.first_name
					   ,epp.EMP_EFFECTIVE_START_DATE as effective_start_date
					   --,epp.EMP_EFFECTIVE_START_DATE AS first_eff_date
					   ,to_date(to_char('31/12/4712'),'dd/mm/yyyy') as effective_end_date
					  -- ,paa.effective_end_date as effective_end_date
					   ,fabu.bu_name
					   ,PAMMF.Value	"FTE"
					   ,pd.name as department_name
					   ,lookup_contract.meaning "CONTRACT"
					   ,epp.situation as C1_C2_DIR
					   ,epp_freeze.situation as C1_C2_DIR_FREEZE
					   ,paa.reason_code
					   ,sal.SALARY_AMOUNT
					   ,pps.actual_termination_date
					  -- ,'PROFILE' as ASS_TYPE
			from PER_ALL_PEOPLE_F paf
			inner join emp_profiles epp on epp.person_id = paf.person_id
			left join my_plan_date pld on 1=1
			inner join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
			inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and assignment_type='E'  and epp.EMP_EFFECTIVE_START_DATE between paa.effective_start_date and paa.effective_end_date --and ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
			left join PER_CONTRACTS_F pcf on pcf.person_id=paa.person_id and pcf.contract_id=paa.contract_id
			left join FND_LOOKUP_VALUES_TL lookup_contract on pcf.type = lookup_contract.lookup_code and lookup_contract.lookup_type = 'CONTRACT_TYPE' and lookup_contract.language = 'F' /*Param*/
			left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date
			inner join per_periods_of_service pps on paa.person_id = pps.person_id and paa.period_of_service_id = pps.period_of_service_id
			left join CMP_SALARY sal on sal.person_id = paa.person_id and sal.assignment_id=paa.assignment_id and epp.EMP_EFFECTIVE_START_DATE between sal.date_from and sal.date_to
			left join per_departments pd on paa.organization_id = pd.organization_id
			left join FUN_ALL_BUSINESS_UNITS_V fabu on paa.BUSINESS_UNIT_ID = fabu.BU_ID
			left join PER_ASSIGN_WORK_MEASURES_F PAMMF on paa.assignment_id = PAMMF.assignment_id and PAMMF.unit = 'FTE' and paa.effective_start_date between PAMMF.effective_start_date and PAMMF.effective_end_date
			left join HR_LOCATIONS_ALL hla on paa.location_id = hla.location_id
			where 1=1 
			and pld.freeze_date between ppn.effective_start_date and ppn.effective_end_date
			and pld.freeze_date between pd.effective_start_date and pd.effective_end_date
			and pld.freeze_date between paf.effective_start_date and paf.effective_end_date
					and pld.freeze_date between pcf.effective_start_date and pcf.effective_end_date
			and paf.person_number like (:Person_number_param) /*param*/
			/*and fabu.bu_name = 'CASA ES' param*/
),

my_assignments_salary as
(
	select 				'SALARY'
					   ,paf.person_number
					   ,paf.person_id
					   ,ppn.last_name
					   ,ppn.first_name
					   ,sal.DATE_FROM as effective_start_date
					   --,sal.DATE_FROM AS first_eff_date
					   ,sal.DATE_TO as effective_end_date
					   ,fabu.bu_name
					   ,PAMMF.Value	"FTE"
					   ,pd.name as department_name
					   ,lookup_contract.meaning "CONTRACT"
					   ,epp.situation as C1_C2_DIR
					   ,epp_freeze.situation as C1_C2_DIR_FREEZE
					   ,sal.SALARY_REASON_CODE
					   ,sal.SALARY_AMOUNT
					   ,pps.actual_termination_date
					--   ,'SALARY' as ASS_TYPE
			from PER_ALL_PEOPLE_F paf
			inner join CMP_SALARY sal on sal.person_id = paf.person_id
			left join my_plan_date pld on 1=1
			inner join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
			inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = sal.person_id and paa.assignment_id=sal.assignment_id and paa.assignment_type='E'  and sal.date_from between paa.effective_start_date and paa.effective_end_date
			left join PER_CONTRACTS_F pcf on pcf.person_id=paa.person_id and pcf.contract_id=paa.contract_id
				left join FND_LOOKUP_VALUES_TL lookup_contract on pcf.type = lookup_contract.lookup_code and lookup_contract.lookup_type = 'CONTRACT_TYPE' and lookup_contract.language = 'F' /*Param*/
			inner join per_periods_of_service pps on paa.person_id = pps.person_id and paa.period_of_service_id = pps.period_of_service_id
			left join emp_profiles epp on epp.person_id =paf.person_id and EMP_EFFECTIVE_START_DATE<=paa.effective_start_date
			left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date
			left join PER_ALL_ASSIGNMENTS_F paa2 on paa2.person_id = paf.person_id and paa2.assignment_type='E'  and epp.EMP_EFFECTIVE_START_DATE between paa2.effective_start_date and paa2.effective_end_date --and ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
			left join per_departments pd on paa.organization_id = pd.organization_id
			left join FUN_ALL_BUSINESS_UNITS_V fabu on paa.BUSINESS_UNIT_ID = fabu.BU_ID
			left join PER_ASSIGN_WORK_MEASURES_F PAMMF on paa.assignment_id = PAMMF.assignment_id and PAMMF.unit = 'FTE' and paa.effective_start_date between PAMMF.effective_start_date and PAMMF.effective_end_date
			left join HR_LOCATIONS_ALL hla on paa.location_id = hla.location_id
			where 1=1 
			and pld.freeze_date between ppn.effective_start_date and ppn.effective_end_date
			and pld.freeze_date between pd.effective_start_date and pd.effective_end_date
			and pld.freeze_date between paf.effective_start_date and paf.effective_end_date
					and pld.freeze_date between pcf.effective_start_date and pcf.effective_end_date
			and paf.person_number like (:Person_number_param) /*param*/
			/*and fabu.bu_name = 'CASA ES' param*/
),

my_total_assignments as(
select * from my_assignments
union all
select * from my_assignments_profile
UNION all
select * from my_assignments_salary
),

my_total_assignments_wrk as (
select mta.*
	,LAG(effective_start_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS prev_eff_start_date_mtaw
	,LAG(effective_end_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS prev_eff_end_date_mtaw
	,LEAD(effective_start_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS next_eff_start_date_mtaw
	,LEAD(effective_end_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS next_eff_end_date_mtaw
from my_total_assignments mta),

my_total_assignments_without_duplicate as (
select 			    mtaw.person_number
					,mtaw.person_id
					,mtaw.last_name
					,mtaw.first_name
					,mtaw.effective_start_date
					,mtaw.effective_end_date
					,mtaw.bu_name
					,mtaw.FTE
					,mtaw.CONTRACT
					,mtaw.department_name
					,mtaw.C1_C2_DIR
					,mtaw.C1_C2_DIR_FREEZE
					,mtaw.reason_code
					,mtaw.SALARY_AMOUNT
					,mtaw.actual_termination_date
					,pld.start_date
					,LAG(effective_start_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS prev_eff_start_date
					,LAG(effective_end_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS prev_eff_end_date
					,LEAD(effective_start_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS next_eff_start_date
					,LEAD(effective_end_date) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS next_eff_end_date
					,LEAD(reason_code) OVER (PARTITION BY person_id ORDER BY effective_start_date, effective_end_date) AS next_reason_code
					--,FIRST_VALUE(mtaw.effective_start_date) OVER (PARTITION BY mtaw.person_id,mtaw.bu_name,mtaw.FTE,mtaw.department_name ORDER BY mtaw.person_id, mtaw.effective_start_date) AS first_eff_date
					--,LAST_VALUE(mtaw.effective_start_date) OVER (PARTITION BY mtaw.person_id,mtaw.bu_name,mtaw.FTE,mtaw.department_name ORDER BY mtaw.person_id, mtaw.effective_start_date) AS last_eff_date
		from my_total_assignments_wrk mtaw
		left join my_plan_date pld on 1=1
where 1=1
and not (mtaw.effective_start_date=mtaw.prev_eff_start_date_mtaw and  mtaw.effective_end_date= mtaw.next_eff_end_date_mtaw)
and  mtaw.effective_end_date > pld.start_date
order by mtaw.effective_start_date, mtaw.effective_end_date),



effective_end_date_corrected as(
select 
	 person_number
	,person_id
	,last_name
	,first_name
	,bu_name
	,FTE
	,CONTRACT
	,department_name
	,C1_C2_DIR
	,reason_code
	,SALARY_AMOUNT
	,CASE 
		WHEN actual_termination_date is null THEN to_date(to_char('31/12/4712'),'dd/mm/yyyy')
		ELSE actual_termination_date
	END as actual_termination_date
	,effective_start_date
	,effective_end_date
	,next_eff_start_date
	,next_eff_end_date
	,CASE
		WHEN effective_start_date < pld.start_date THEN pld.start_date
		WHEN effective_start_date > pld.end_date THEN to_date(to_char('31/12/4712'),'dd/mm/yyyy')
		WHEN C1_C2_DIR_FREEZE is null and REASON_CODE='MIG' and effective_start_date<add_months(trunc(pld.start_date,'Q')-1,3) +1 /*end_of_Q1*/ THEN TRUNC(pld.start_date, 'YEAR') /*begin_year*/
		ELSE effective_start_date
	END as effective_start_date_corrected
	,CASE
		WHEN EFFECTIVE_END_DATE = to_date(to_char('31/12/4712'),'dd/mm/yyyy') and NEXT_EFF_START_DATE is not null then NEXT_EFF_START_DATE-1
		WHEN effective_end_date > pld.end_date and EFFECTIVE_END_DATE = to_date(to_char('31/12/4712'),'dd/mm/yyyy') THEN add_months(trunc(pld.start_date,'Q')-1,12) /*end_of_year*/
		WHEN effective_end_date > pld.end_date THEN pld.start_date
		WHEN effective_end_date < pld.start_date THEN to_date(to_char('31/12/4712'),'dd/mm/yyyy')
		WHEN C1_C2_DIR_FREEZE is null and next_reason_code='MOG' and effective_end_date>add_months(trunc(pld.start_date,'Q')-1,9)+1  /*end_of_Q3*/ THEN add_months(trunc(pld.start_date,'Q')-1,12) /*end_of_year*/
		WHEN C1_C2_DIR_FREEZE is not null and NEXT_EFF_START_DATE-1 = ACTUAL_TERMINATION_DATE THEN ACTUAL_TERMINATION_DATE
		WHEN EFFECTIVE_END_DATE>NEXT_EFF_START_DATE THEN NEXT_EFF_START_DATE-1
		WHEN EFFECTIVE_END_DATE is null THEN NEXT_EFF_START_DATE-1
		ELSE effective_end_date
	END as effective_end_date_corrected
from my_total_assignments_without_duplicate
left join my_plan_date pld on 1=1
order by effective_start_date_corrected,effective_end_date_corrected),

my_real_phase as (
select * from effective_end_date_corrected
left join my_plan_date pld on 1=1
where EFFECTIVE_START_DATE_CORRECTED<actual_termination_date
and EFFECTIVE_END_DATE_CORRECTED >= pld.start_date),

my_real_phase_adjusted as (
select 	a.*
		,CASE
			WHEN EFFECTIVE_END_DATE_CORRECTED= add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/ THEN add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/
			WHEN EFFECTIVE_END_DATE_CORRECTED= ADD_MONTHS(TRUNC(start_date, 'YEAR'), 12)-1/24/60/60 /*end_of_year*/ THEN add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/
			WHEN EFFECTIVE_END_DATE_CORRECTED = ACTUAL_TERMINATION_DATE THEN EFFECTIVE_END_DATE_CORRECTED
			ELSE LEAD(EFFECTIVE_START_DATE_CORRECTED) OVER (ORDER BY EFFECTIVE_START_DATE_CORRECTED)
		END As EFFECTIVE_END_DATE_ADJUSTED
from (
	select 	mrp.* 
			,person_id||bu_name||FTE||CONTRACT||department_name|| SALARY_AMOUNT as KEY
			,LAG(person_id||bu_name||FTE||CONTRACT||department_name|| SALARY_AMOUNT || C1_C2_DIR ) OVER (PARTITION BY person_id,bu_name,FTE,CONTRACT,department_name, SALARY_AMOUNT, C1_C2_DIR ORDER BY EFFECTIVE_START_DATE_CORRECTED) As PREV_KEY
	from my_real_phase mrp) a
where PREV_KEY is null
order by EFFECTIVE_START_DATE_CORRECTED, EFFECTIVE_END_DATE_CORRECTED)

select 	person_number
		,person_id
		,last_name
		,first_name
		,bu_name
		,FTE
		,CONTRACT
		,department_name
		,C1_C2_DIR
		,reason_code
		,SALARY_AMOUNT
		,EFFECTIVE_START_DATE_CORRECTED
		,EFFECTIVE_END_DATE_ADJUSTED
		,EFFECTIVE_END_DATE_ADJUSTED-EFFECTIVE_START_DATE_CORRECTED +1 as PRESENCE_CALENDAIRE_AJUSTEE
from my_real_phase_adjusted

/*
- Suppression de la phase en cours car au niveau du plan / A FAIRE EN DERNIER
- Ajout des phases en cas de changements de contrats --> Vérifier les règles en vigueur
- Check vs les règles d'éligibilité et cohérence Fast Formula
- Ajout des phases en cas de passage à population régalienne
- Ajout des conversions de devises
- Ajout du taux cible
- Intégrer l’Assignment N° du collab (ce point j’ai oublié de te le remonter) 
- Retirer de la requête les C1 ayant effectué une Mobilité Intra-Groupe (car cela sera géré au niveau de la double ligne de la feuille de travail)
*/

