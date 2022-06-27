with my_plan_date as(					
select 	cmp_plan.plan_id, 
		cpm_lang.plan_name, 
		cmp_period.period_name,
		cmp_period.start_date,
		cmp_period.end_date,
		cmp_period.freeze_date 
from cmp_plans_b cmp_plan
inner join cmp_plan_periods cmp_period on cmp_plan.plan_id = cmp_period.plan_id
inner join cmp_plans_tl cpm_lang on cmp_plan.plan_id = cpm_lang.plan_id and cpm_lang.LANGUAGE = 'US'
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
	and CT.language='F'
	and HPI.SECTION_ID='300000003197644' /*param à vérifier lors de la migration d'environnements*/
	and paf.person_number= 'PNE_PHASE_02' /*param*/
	and ((HPI.ATTRIBUTE_DATE2 is not null) or (HPI.ATTRIBUTE_DATE1 is not null))
),

my_assignments as (
select 		paf.person_number
				   ,paf.person_id
				   ,ppn.last_name
				   ,ppn.first_name
				   ,paa.effective_start_date
				   ,FIRST_VALUE(paa.effective_start_date) OVER (PARTITION BY paf.person_id,fabu.bu_name,PAMMF.Value,pd.name ORDER BY paf.person_id, paa.effective_start_date) AS first_eff_date
				   ,paa.effective_end_date
				   ,fabu.bu_name
				   ,PAMMF.Value	"FTE"
				   ,pd.name as department_name
				   ,epp.situation as C1_C2_DIR
		from PER_ALL_PEOPLE_F paf
		left join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and assignment_type='E' and ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
		left join my_plan_date pld on 1=1
		left join emp_profiles epp on epp.person_id =paf.person_id and EMP_EFFECTIVE_START_DATE<=paa.effective_start_date
		left join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
		left join per_departments pd on paa.organization_id = pd.organization_id
		left join FUN_ALL_BUSINESS_UNITS_V fabu on paa.BUSINESS_UNIT_ID = fabu.BU_ID
		left join PER_ASSIGN_WORK_MEASURES_F PAMMF on paa.assignment_id = PAMMF.assignment_id and PAMMF.unit = 'FTE' and paa.effective_start_date between PAMMF.effective_start_date and PAMMF.effective_end_date
		left join HR_LOCATIONS_ALL hla on paa.location_id = hla.location_id
		where 1=1 
		and pld.freeze_date between ppn.effective_start_date and ppn.effective_end_date
		and pld.freeze_date between pd.effective_start_date and pd.effective_end_date
		and pld.freeze_date between paf.effective_start_date and paf.effective_end_date
		and paf.person_number ='PNE_PHASE_02' /*param*/
		and fabu.bu_name = 'CASA ES' /*param*/
),

my_assignments_profile as
(
	select 		paf.person_number
					   ,paf.person_id
					   ,ppn.last_name
					   ,ppn.first_name
					   ,epp.EMP_EFFECTIVE_START_DATE
					   ,epp.EMP_EFFECTIVE_START_DATE AS first_eff_date
					   ,null as effective_end_date
					   ,fabu.bu_name
					   ,PAMMF.Value	"FTE"
					   ,pd.name as department_name
					   ,epp.situation as C1_C2_DIR
			from PER_ALL_PEOPLE_F paf
			inner join emp_profiles epp on epp.person_id = paf.person_id
			left join my_plan_date pld on 1=1
			left join PER_PERSON_NAMES_F PPN on paf.person_id = ppn.person_id and ppn.name_type='GLOBAL'
			left join PER_ALL_ASSIGNMENTS_F paa on paa.person_id = paf.person_id and assignment_type='E' and ASSIGNMENT_STATUS_TYPE = 'ACTIVE' and epp.EMP_EFFECTIVE_START_DATE between paa.effective_start_date and paa.effective_end_date
			left join per_departments pd on paa.organization_id = pd.organization_id
			left join FUN_ALL_BUSINESS_UNITS_V fabu on paa.BUSINESS_UNIT_ID = fabu.BU_ID
			left join PER_ASSIGN_WORK_MEASURES_F PAMMF on paa.assignment_id = PAMMF.assignment_id and PAMMF.unit = 'FTE' and paa.effective_start_date between PAMMF.effective_start_date and PAMMF.effective_end_date
			left join HR_LOCATIONS_ALL hla on paa.location_id = hla.location_id
			where 1=1 
			and pld.freeze_date between ppn.effective_start_date and ppn.effective_end_date
			and pld.freeze_date between pd.effective_start_date and pd.effective_end_date
			and pld.freeze_date between paf.effective_start_date and paf.effective_end_date
			and paf.person_number ='PNE_PHASE_02' /*param*/
			and fabu.bu_name = 'CASA ES' /*param*/
),

my_total_assignments as(
select * from my_assignments
union 
select * from my_assignments_profile
),

my_phases as (
	select 
	person_number
	,person_id
	,last_name
	,first_name
	,effective_start_date
	,first_eff_date
	,FIRST_VALUE(effective_start_date) OVER (PARTITION BY person_id ORDER BY person_id, effective_start_date) AS first_date_ass
	,LAST_VALUE(effective_start_date) OVER (PARTITION BY person_id ORDER BY person_id, effective_start_date) AS last_date_ass
	,LEAD(effective_start_date) OVER (PARTITION BY person_id ORDER BY effective_start_date) AS next_eff_start_date
	,LEAD(effective_end_date) OVER (PARTITION BY person_id ORDER BY effective_start_date) AS next_eff_end_date
	,effective_end_date
	,bu_name
	,fte
	,department_name
	,C1_C2_DIR
	from my_total_assignments
	where 1=1
	and effective_start_date=first_eff_date
),

my_phase_right_dates as(
SELECT
person_number
,mp.person_id
,last_name
,first_name
,CASE 
	WHEN effective_start_date < pld.start_date THEN pld.start_date
	ELSE effective_start_date
END as effective_start_date
--,first_eff_date
--,next_eff_start_date
,next_eff_end_date
--,effective_end_date
,CASE
	WHEN effective_end_date is null and next_eff_start_date is null THEN pld.end_date
	WHEN effective_end_date<>next_eff_start_date+1 THEN next_eff_start_date-1
	WHEN effective_end_date is null THEN next_eff_start_date-1
	WHEN effective_end_date>pld.end_date THEN pld.end_date
	ELSE effective_end_date
END as effective_end_date
,bu_name
,fte
,department_name 
,C1_C2_DIR
,epp2.situation AS LAST_SITUATION
,first_date_ass
,last_date_ass
,trunc(pld.start_date, 'YEAR') begin_year
,add_months(trunc(pld.start_date, 'YEAR'), 12)-1/24/60/60 end_of_year
,add_months(trunc(pld.start_date, 'YEAR'), 3)-1/24/60/60 end_of_Q1
,add_months(trunc(pld.start_date, 'YEAR'), 9)-1/24/60/60 end_of_Q3
from my_phases mp
left join emp_profiles epp2 on epp2.person_id = mp.person_id
left join my_plan_date pld on 1=1
order by effective_start_date
),

my_phase_right_dates_including_quarter as(
SELECT
person_number
,person_id
,last_name
,first_name
,CASE 
	WHEN last_situation is null and effective_start_date = first_date_ass and effective_start_date <= end_of_Q1 THEN begin_year /*Date à passer en param*/
	ELSE effective_start_date
END as effective_start_date
,CASE 
	WHEN last_situation is null and effective_end_date = last_date_ass and effective_end_date >= end_of_Q3 THEN end_of_year /*Date à passer en param*/
	ELSE effective_end_date
END as effective_end_date
--,first_eff_date
--,next_eff_start_date
--,next_eff_end_date
--,effective_end_date
--,effective_end_date
,bu_name
,fte
,department_name 
,C1_C2_DIR
,LAST_SITUATION
from my_phase_right_dates,my_plan_date pld
order by effective_start_date
),

my_phase_and_date_diff as(
SELECT
	person_number
	,person_id
	,last_name
	,first_name
	,effective_start_date
	,effective_end_date
	,(effective_end_date - effective_start_date + 1) as "Présence calendaire ajusté"
	,bu_name
	,fte
	,department_name 
	,LAST_SITUATION as Situation
FROM my_phase_right_dates_including_quarter
)


select * from my_phase_and_date_diff

/*ne pas recaller la date de quarter si le collab passe de tout collab à C2 en cours d'année --> DONE*/
/*gérer le passage à une autre et depuis une autre entité Groupe*/
/*ajouter les données salaires*/
/*ajouter les données contrats*/
/*vérifier les règles d'éligibilité - par exemple en cas d'alternance / enchainement de CDD*/
/*Récupérer les salaires historiques dans la devise du salary basis en vigueur/*