--LDP TO METADB
-CR215
--Unique Title (Instance) Counts
--Query writer: Vandana Shah (vp25)
--Query reviewers: Joanne Leary (jl41), Linda Miller (lm15)
/*This query provides counts of unique titles (instances) of physical items (excluding microforms), by format type. It does not include microform counts. This query is primarily used to report on annual counts. */
--NOTE: Some microforms as well as unpurchased materials get included in the results; these are flagged and should be filtered out from final counts. 

WITH
 			
marc_formats AS
	(SELECT 
 		DISTINCT 
 		sm.instance_id,
       	substring(sm."content", 7, 2) AS "leader0607"
     	FROM folio_source_record.marc__t AS sm  
    	WHERE  sm.field = '000'),

 --Flagging microforms via 007 field
micros AS
	(SELECT DISTINCT 
		sm.instance_id,
		substring (sm."content",1,1) AS micro_by_007
          FROM folio_source_record.marc__t AS sm
          WHERE  sm.field = '007'  AND substring (sm."content",1,1) = 'h'
                ),

--Flagging unpurchased
unpurch AS
(SELECT 
     DISTINCT sm.instance_id,
     sm."content"  AS "unpurchased"
      FROM folio_source_record.marc__t AS sm  
WHERE sm.field LIKE '899'
    AND sm.sf LIKE 'a'
    AND sm."content" ILIKE 'couttspdbappr'
 ),     
    
     
 merge1 AS
(SELECT DISTINCT
    	he.instance_id,
     	mf.leader0607, 
 		up.unpurchased,
     	fmg.leader0607description,
		fmg.folio_format_type,
		fmg.folio_format_type_adc_groups, 
		fmg.folio_format_type_acrl_nces_groups,
		mc.micro_by_007
   	   	   	
   	FROM folio_derived.holdings_ext AS he
   	LEFT JOIN marc_formats AS mf ON he.instance_id::uuid = mf.instance_id
 	LEFT JOIN micros AS mc ON he.instance_id::uuid = mc.instance_id
   	LEFT JOIN unpurch AS up ON he.instance_id::uuid = up.instance_id
   	LEFT JOIN folio_derived.instance_ext AS ie ON he.instance_id = ie.instance_id 
   	LEFT JOIN vp25.vs_folio_physical_material_formats AS fmg ON mf.leader0607=fmg.leader0607
     	 
 /*Excludes serv,remo which are all e-materials and are counted in a separate query. Also excludes materials 
* from the following locations as they: no longer exist; are not yet received/cataloged; are not owned by the Library; etc.
* Also excludes microforms and items not yet cataloged via call number and/or title.*/


   	
WHERE 
   (he.permanent_location_name NOT ILIKE ALL(ARRAY['serv,remo','Borrow Direct', 'CCSS', 'cons,opt', 'LTS Review Shelves', 'Engineering',
'Engr,wpe', 'Law Technical Services', 'LTS E-Resources & Serials', 'Mann Gateway', 'Mann Hortorium', 'Mann Hortorium Reference', 'Mann Technical Services',
'Interlibrary Loan – Olin', 'Phys Sci', 'Agricultural Engineering', 'Bindery Circulation', 'Biochem Reading Room', 'Engineering Reference',
'Entomology', 'Fine Arts Course Reserve', 'Food Science', 'Nestle Library Permanent Reserve', 'Nestle Library Reserve', 'JGSM Permanent Reserve',
'Mann Permanent Reserve', 'Iron Mountain', 'RMC Technical Services', 'Vet Permanent Reserve', 'Vet Reference', 'No Library', 'x-test','z-test location'])) 


--exclude the following materials as they are not available for discovery or are micro-materials
AND he.call_number NOT ILIKE ALL(ARRAY['on order%', 'in process%', 'Available for the library to purchase', 
 'On selector%', '%film%','%fiche%', '%micro%', '%vault%']) 
--AND (he.discovery_suppress IS NOT TRUE OR he.discovery_suppress IS NULL OR he.discovery_suppress ='FALSE')
AND (he.discovery_suppress != 'false') -- IN the metadb DERIVED TABLE 'holdings_ext', the discovery_supress column is a text values column and not a boolean values COLUMN, so cannot use 'IS NOT TRUE'. 

AND (he.permanent_location_name IS NOT NULL)
AND (ie.title NOT ILIKE '%[microform]%')
AND (ie.discovery_suppress IS NOT TRUE OR ie.discovery_suppress IS NULL OR ie.discovery_suppress = 'FALSE')
--AND (mc.micro_by_007 NOT LIKE 'h')
)

SELECT 
current_date,
COUNT (DISTINCT mg.instance_id) AS distinct_title_count,
mg.leader0607,
mg.leader0607description,
mg.folio_format_type,
mg.folio_format_type_adc_groups, 
mg.folio_format_type_acrl_nces_groups,
mg.unpurchased,
mg.micro_by_007


FROM merge1 AS mg
LEFT JOIN vp25.vs_folio_physical_material_formats AS fmg ON mg.leader0607=fmg.leader0607
GROUP BY 

mg.leader0607,
mg.leader0607description,
mg.folio_format_type,
mg.folio_format_type_adc_groups, 
mg.folio_format_type_acrl_nces_groups,
mg.unpurchased,
mg.micro_by_007
;
