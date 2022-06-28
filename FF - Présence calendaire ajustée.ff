/*Récupérer l'assignement traité à la date d'extraction du plan*/
/*Récupérer la date de début de periode du plan CMP_IV_PLAN_START_DATE => "DATE_DEBUT_PERIOD_PLAN" */
/*Récupérer la date de fin de periode du plan CMP_IV_PLAN_END_DATE => "DATE_FIN_PERIOD_PLAN" */

/*Vérifier si le collaborateur (PERSON_ID) est dans la table des assignment segments*/
	/*SI le collaborateur n'est PAS dans la table des assignments segments alors l'assignment est sur la dernière phase*/
		-- THEN 
				/*Récupération de la date de début de phase "DATE_DEBUT" */
					--récupérer la première EFFECTIVE_START_DATE de l'assignment en cours (si multi-occurence sur l'assignment) "FIRST_DATE_ASSIGNMENT"
						--si FIRST_DATE_ASSIGNMENT < DATE_DEBUT_PERIOD_PLAN => DATE_DEBUT = DATE_DEBUT_PERIOD_PLAN
						--sinon DATE_DEBUT = FIRST_DATE_ASSIGNMENT
				/*Récupération de la date de début de phase "DATE_FIN" */
					--récupérer l'EFFECTIVE_END_DATE de l'assignment en cours "LAST_DATE_ASSIGNMENT"
						--si LAST_DATE_ASSIGNMENT > DATE_FIN_PERIOD_PLAN => DATE_FIN = DATE_FIN_PERIOD_PLAN
						--sinon DATE_FIN = LAST_DATE_ASSIGNMENT
				
	/*SI le collaborateur EST dans la table des assignments segments alors l'assignment est sur la dernière phase*/
		-- ELSE
				/*Récupération de la date de début de phase "DATE_DEBUT" */
				--récupérer la l'occurence de phase dans assignment segment pour la MAX(EFFECTIVE START DATE) pour le collaborateur = LAST_DATE_PHASE
				--DATE_DEBUT = LAST_DATE_PHASE
				
				/*Récupération de la date de début de phase "DATE_FIN" */
					--récupérer l'EFFECTIVE_END_DATE de l'assignment en cours "LAST_DATE_ASSIGNMENT"
						--si LAST_DATE_ASSIGNMENT > DATE_FIN_PERIOD_PLAN => DATE_FIN = DATE_FIN_PERIOD_PLAN
						--sinon DATE_FIN = LAST_DATE_ASSIGNMENT						
	
	/*Mettre Date Fin dans une table de LOG*/

/*Calcul de la Présence Calendaire ajusté*/
--PERIODE_CALENDAIRE_AJUSTE = DAYS_BETWEEN(DATE_FIN,DATE_DEBUT)+1

--Retourner PERIODE_CALENDAIRE_AJUSTE