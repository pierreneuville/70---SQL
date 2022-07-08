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
and plan_name ='Pilot Plan V.4 - Assignment Segment v2' /*param*/
and period_name='Plan - 2022' /*param*/
order by 1),


emp_profiles as (
	select
		person_id
		,SITUATION
		,EMP_EFFECTIVE_START_DATE
		,CASE 
			WHEN LAST_VALUE(EMP_EFFECTIVE_START_DATE) OVER (PARTITION BY person_id ORDER BY EMP_EFFECTIVE_START_DATE ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) = EMP_EFFECTIVE_START_DATE THEN 'Y' 
			ELSE 'N'
		END AS last_situation
	from(
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
		) emp
),

my_assignments as (
select 				'ASSIGNMENT'
				   ,paf.person_number
				   ,paf.person_id
				   ,ppn.last_name
				   ,ppn.first_name
				   ,paa.effective_start_date
				   ,paa.effective_end_date
				   ,fabu.bu_name
				   ,PAMMF.Value	"FTE"
				   ,pd.name as department_name
				   ,lookup_contract.meaning "CONTRACT"
				   ,epp.situation as C1_C2_DIR
				   ,epp_freeze.situation as C1_C2_DIR_FREEZE
				   ,paa.reason_code
				   ,sal.SALARY_AMOUNT
				   ,sal.CURRENCY_CODE as CURRENCY
				   ,pps.actual_termination_date
				   --,'ASSIGNMENT' as ASS_TYPE
		from PER_ALL_PEOPLE_F paf
		inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and assignment_type='E'
		inner join per_periods_of_service pps on paa.person_id = pps.person_id and paa.period_of_service_id = pps.period_of_service_id
		left join my_plan_date pld on 1=1
		left join emp_profiles epp on epp.person_id =paf.person_id and epp.EMP_EFFECTIVE_START_DATE<=paa.effective_start_date
		left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date and epp_freeze.last_situation='Y'
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
					   ,sal.CURRENCY_CODE as CURRENCY
					   ,pps.actual_termination_date
					  -- ,'PROFILE' as ASS_TYPE
			from PER_ALL_PEOPLE_F paf
			inner join emp_profiles epp on epp.person_id = paf.person_id
			left join my_plan_date pld on 1=1
			inner join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
			inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and assignment_type='E'  and epp.EMP_EFFECTIVE_START_DATE between paa.effective_start_date and paa.effective_end_date --and ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
			left join PER_CONTRACTS_F pcf on pcf.person_id=paa.person_id and pcf.contract_id=paa.contract_id
			left join FND_LOOKUP_VALUES_TL lookup_contract on pcf.type = lookup_contract.lookup_code and lookup_contract.lookup_type = 'CONTRACT_TYPE' and lookup_contract.language = 'F' /*Param*/
			left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date and epp_freeze.last_situation='Y'
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
					   ,sal.CURRENCY_CODE as CURRENCY
					   ,pps.actual_termination_date
					--   ,'SALARY' as ASS_TYPE
			from PER_ALL_PEOPLE_F paf
			inner join CMP_SALARY sal on sal.person_id = paf.person_id
			left join my_plan_date pld on 1=1
			inner join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
			inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = sal.person_id and paa.assignment_type='E'  and sal.date_from between paa.effective_start_date and paa.effective_end_date
			left join PER_CONTRACTS_F pcf on pcf.person_id=paa.person_id and pcf.contract_id=paa.contract_id
				left join FND_LOOKUP_VALUES_TL lookup_contract on pcf.type = lookup_contract.lookup_code and lookup_contract.lookup_type = 'CONTRACT_TYPE' and lookup_contract.language = 'F' /*Param*/
			inner join per_periods_of_service pps on paa.person_id = pps.person_id and paa.period_of_service_id = pps.period_of_service_id
			left join emp_profiles epp on epp.person_id =paf.person_id and EMP_EFFECTIVE_START_DATE<=sal.DATE_FROM
			left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date and epp_freeze.last_situation='Y'
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

my_assignments_elements as
(
			select 'ELEMENT'
				   ,paf.person_number
				   ,paf.person_id
				   ,ppn.last_name
				   ,ppn.first_name
				   ,peev.effective_start_date as effective_start_date
				   ,peev.effective_end_date as effective_end_date
				   ,fabu.bu_name
				   ,PAMMF.Value	"FTE"
				   ,pd.name as department_name
				   ,epp.situation as C1_C2_DIR
				   ,epp_freeze.situation as C1_C2_DIR_FREEZE
				   ,'ELEMENT_REASON' as ELEMENT_REASON
				   ,PEEV.SCREEN_ENTRY_VALUE
				   ,pps.actual_termination_date
				   -- ,'ELEMENT' as ASS_TYPE
			from PER_ALL_PEOPLE_F paf
			inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and paa.assignment_type='E'  
			inner join pay_rel_groups_dn prg on paa.assignment_id = prg.assignment_id and sysdate between prg.start_date and prg.end_date
			left join pay_entry_usages peu on prg.RELATIONSHIP_GROUP_ID = peu.payroll_assignment_id
			left join pay_element_entry_values_f peev on peu.element_entry_id = peev.element_entry_id
				inner JOIN PAY_INPUT_VALUES_F PIV ON PEEV.INPUT_VALUE_ID = PIV.INPUT_VALUE_ID and PIV.BASE_NAME = 'Percentage'
			left join pay_element_entries_f peef on peu.element_entry_id = peef.element_entry_id
			left join pay_element_types_tl pet on peef.element_type_id = pet.element_type_id and pet.language = 'F'/*parameter*/
			INNER JOIN PAY_ELEMENT_TYPES_F PETF ON PETF.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID AND PETF.ELEMENT_TYPE_ID NOT IN (SELECT ELEMENT_TYPE_ID FROM CMP_SALARY_BASES) and PETF.BASE_ELEMENT_NAME in ('FRA_Bonus cible %')/*To be adapted*/			
			left join my_plan_date pld on 1=1
			inner join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
			left join PER_CONTRACTS_F pcf on pcf.person_id=paa.person_id and pcf.contract_id=paa.contract_id
				left join FND_LOOKUP_VALUES_TL lookup_contract on pcf.type = lookup_contract.lookup_code and lookup_contract.lookup_type = 'CONTRACT_TYPE' and lookup_contract.language = 'F' /*Param*/
			inner join per_periods_of_service pps on paa.person_id = pps.person_id and paa.period_of_service_id = pps.period_of_service_id
			left join emp_profiles epp on epp.person_id =paf.person_id and EMP_EFFECTIVE_START_DATE<=peev.effective_start_date
			left join emp_profiles epp_freeze on epp_freeze.person_id =paf.person_id and epp_freeze.EMP_EFFECTIVE_START_DATE<= pld.freeze_date and epp_freeze.last_situation='Y'
			left join PER_ALL_ASSIGNMENTS_F paa2 on paa2.person_id = paf.person_id and paa2.assignment_type='E'  and epp.EMP_EFFECTIVE_START_DATE between paa2.effective_start_date and paa2.effective_end_date --and ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
			left join per_departments pd on paa.organization_id = pd.organization_id
			left join FUN_ALL_BUSINESS_UNITS_V fabu on paa.BUSINESS_UNIT_ID = fabu.BU_ID
			left join PER_ASSIGN_WORK_MEASURES_F PAMMF on paa.assignment_id = PAMMF.assignment_id and PAMMF.unit = 'FTE' and paa.effective_start_date between PAMMF.effective_start_date and PAMMF.effective_end_date
			left join HR_LOCATIONS_ALL hla on paa.location_id = hla.location_id
			where 1=1 
			and peev.effective_start_date between paa.effective_start_date and paa.effective_end_date
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
UNION all 
select * from my_assignments_elements
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
					,mtaw.CURRENCY
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
and not (
			mtaw.effective_start_date=mtaw.prev_eff_start_date_mtaw 
		and mtaw.effective_end_date= mtaw.next_eff_end_date_mtaw
		and mtaw.prev_eff_start_date_mtaw is not null
		and mtaw.next_eff_end_date_mtaw is not null
		)
and  mtaw.effective_end_date >= pld.start_date
order by mtaw.effective_start_date, mtaw.effective_end_date),



effective_date_corrected as(
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
	,CURRENCY
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
	--,pld.freeze_date
from my_total_assignments_without_duplicate
left join my_plan_date pld on 1=1
order by effective_start_date_corrected,effective_end_date_corrected),

my_real_phase as (
select * from effective_date_corrected
left join my_plan_date pld on 1=1
where EFFECTIVE_START_DATE_CORRECTED<actual_termination_date
and EFFECTIVE_END_DATE_CORRECTED >= pld.start_date),

my_real_phase_adjusted as (
select 	a.*
		,CASE
			WHEN EFFECTIVE_END_DATE_CORRECTED= add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/ THEN add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/
			WHEN EFFECTIVE_END_DATE_CORRECTED= ADD_MONTHS(TRUNC(start_date, 'YEAR'), 12)-1/24/60/60 /*end_of_year*/ THEN add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/
			WHEN EFFECTIVE_END_DATE_CORRECTED = ACTUAL_TERMINATION_DATE AND C1_C2_DIR is not null THEN EFFECTIVE_END_DATE_CORRECTED
			WHEN EFFECTIVE_END_DATE_CORRECTED = ACTUAL_TERMINATION_DATE AND C1_C2_DIR is null THEN add_months(trunc(start_date,'Q')-1,12) /*end_of_year*/
			ELSE LEAD(EFFECTIVE_START_DATE_CORRECTED-1) OVER (ORDER BY EFFECTIVE_START_DATE_CORRECTED)
		END As EFFECTIVE_END_DATE_ADJUSTED
from (
	select 	mrp.* 
			,person_id||bu_name||FTE||CONTRACT||department_name|| SALARY_AMOUNT as KEY
			,LAG(person_id||bu_name||FTE||CONTRACT||department_name|| SALARY_AMOUNT || C1_C2_DIR ) OVER (PARTITION BY person_id,bu_name,FTE,CONTRACT,department_name, SALARY_AMOUNT, C1_C2_DIR ORDER BY EFFECTIVE_START_DATE_CORRECTED) As PREV_KEY
	from my_real_phase mrp) a
where PREV_KEY is null
order by EFFECTIVE_START_DATE_CORRECTED, EFFECTIVE_END_DATE_CORRECTED),

last_salary_for_assignment as (
select person_id, assignment_id, CURRENCY_CODE from CMP_SALARY sal2
where sal2.date_from = (select max(sal3.date_from) from CMP_SALARY sal3 where sal2.person_id=sal3.person_id and sal2.assignment_id=sal3.assignment_id)
),

my_real_phase_adjusted_and_last_assignment as (
select 	mrpa.person_number
		,mrpa.person_id
		,paa.assignment_id
		,mrpa.last_name
		,mrpa.first_name
		,mrpa.bu_name
		,mrpa.FTE
		,mrpa.CONTRACT
		,mrpa.department_name
		,mrpa.C1_C2_DIR
		,mrpa.reason_code
		,mrpa.SALARY_AMOUNT
		,mrpa.CURRENCY
		,lsfa.CURRENCY_CODE as LAST_CURRENCY_FOR_ASSIGNMENT
		,CASE 
			WHEN mrpa.CURRENCY=lsfa.CURRENCY_CODE THEN 1
			WHEN DR1.CONVERSION_RATE = 0 THEN 1
			ELSE DR1.CONVERSION_RATE
		 END as CONVERSION_RATE
		,mrpa.EFFECTIVE_START_DATE_CORRECTED
		,mrpa.EFFECTIVE_END_DATE_ADJUSTED
		,mrpa.EFFECTIVE_END_DATE_ADJUSTED-mrpa.EFFECTIVE_START_DATE_CORRECTED +1 as PRESENCE_CALENDAIRE_AJUSTEE
		,freeze_date
from my_real_phase_adjusted mrpa 
inner join PER_ALL_ASSIGNMENTS_F paa on paa.person_id=mrpa.person_id and paa.ASSIGNMENT_STATUS_TYPE='ACTIVE' and paa.assignment_type='E' and paa.effective_start_date = (select max(paa2.effective_start_date) from PER_ALL_ASSIGNMENTS_F paa2 where  paa.person_id=paa2.person_id and paa2.assignment_type='E' and paa2.ASSIGNMENT_STATUS_TYPE='ACTIVE' and paa2.effective_start_date<=freeze_date and paa2.business_unit_id = '300000001935917' /*Param critère de lancement*/)
left join last_salary_for_assignment lsfa on paa.person_id=lsfa.person_id and paa.assignment_id=lsfa.assignment_id
left join GL_DAILY_RATES DR1 ON DR1.FROM_CURRENCY=mrpa.CURRENCY and DR1.TO_CURRENCY=lsfa.CURRENCY_CODE and CONVERSION_TYPE='Corporate' and DR1.CONVERSION_DATE = paa.effective_start_date
)

select  
		mrpala.person_number
		,mrpala.person_id
		,mrpala.assignment_id
		,mrpala.last_name
		,mrpala.first_name
		,mrpala.bu_name
		,mrpala.FTE
		,mrpala.CONTRACT
		,mrpala.department_name
		,mrpala.C1_C2_DIR
		,mrpala.reason_code
		,mrpala.SALARY_AMOUNT*mrpala.CONVERSION_RATE as SALARY_AMOUNT_CONVERTED
		,mrpala.LAST_CURRENCY_FOR_ASSIGNMENT
		,mrpala.EFFECTIVE_START_DATE_CORRECTED
		,mrpala.EFFECTIVE_END_DATE_ADJUSTED
		,mrpala.EFFECTIVE_END_DATE_ADJUSTED-mrpala.EFFECTIVE_START_DATE_CORRECTED +1 as PRESENCE_CALENDAIRE_AJUSTEE
		,mrpala.freeze_date
FROM my_real_phase_adjusted_and_last_assignment mrpala

/*
- Suppression de la phase en cours car au niveau du plan / A FAIRE EN DERNIER
- Ajout des phases en cas de changements de contrats --> DONE
- Ajout Assignment_ID --> DONE
- Ajout des conversions de devises --> DONE
- Ajout des phases en cas de passage à population régalienne
- Ajout du taux cible
- Ajouter le cas du C2 qui passe C1 KL100011573_P0 --> DONE
- Ajouter le cas du Tout Collab à C2  KL100011585_P0 --> DONE
- Cas d'un collab sans phase > pas de ligne apparente dans la query KL100011584_P0 --> DONE


Verif
- Ajout des phases en cas de changements de contrats --> Vérifier les règles en vigueur
- Retirer de la requête les C1 ayant effectué une Mobilité Intra-Groupe (car cela sera géré au niveau de la double ligne de la feuille de travail)
*/
