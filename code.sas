libname hana odbc  datasrc=ds_datasphere schema=SAPDS_DWH
user=**************
password="*************************";

libname sourcing 'U:\AperamDWH\Sourcing\Data_output';

%macro formatCol(myCol);
    CATS(INPUT(&myCol, 10.))
%mend;
%macro formatDat(myCol);
    input(&myCol,yymmdd8.)
%mend;
/* Step 1: Create concatenated strings from ZTEKPO with consistent ordering */
PROC SQL;
CREATE TABLE ztekpo_concat AS
SELECT EBELN, EBELP,
    CATX(',', COALESCEC(ZZCOMPOS, '')) AS s_chemicalComponent,
    CATX(',', COALESCEC(PUT(ZZPRBASE, BEST12.), '')) AS f_basePriceInCurrency,
    CATX(',', COALESCEC(ZZCURCOMP, '')) AS s_zzCurrency,
    CATX(',', COALESCEC(PUT(ZZWKURS, BEST12.), '')) AS f_exchangeRate,
    CATX(',', COALESCEC(PUT(ZZANALY11, BEST12.), '')) AS f_analysis1,
    CATX(',', COALESCEC(PUT(ZZANALY12, BEST12.), '')) AS f_analysis2,
    CATX(',', COALESCEC(PUT(ZZANALY13, BEST12.), '')) AS f_analysis3,
    CATX(',', COALESCEC(PUT(ZZMTCMCD, BEST12.), '')) AS f_amount,
    CATX(',', COALESCEC(PUT(ZZMTCMRE, BEST12.), '')) AS f_amount2
FROM hana.ZTEKPO
ORDER BY EBELN, EBELP, ZZCOMPOS;
QUIT;

/* Step 2: Use DATA step to actually concatenate multiple rows */
DATA ztekpo_final;
SET ztekpo_concat;
BY EBELN EBELP;
LENGTH s_chemicalComponent_final f_basePriceInCurrency_final s_zzCurrency_final 
       f_exchangeRate_final f_analysis1_final f_analysis2_final f_analysis3_final 
       f_amount_final f_amount2_final $1000;
RETAIN s_chemicalComponent_final f_basePriceInCurrency_final s_zzCurrency_final 
       f_exchangeRate_final f_analysis1_final f_analysis2_final f_analysis3_final 
       f_amount_final f_amount2_final;

IF FIRST.EBELP THEN DO;
    s_chemicalComponent_final = s_chemicalComponent;
    f_basePriceInCurrency_final = f_basePriceInCurrency;
    s_zzCurrency_final = s_zzCurrency;
    f_exchangeRate_final = f_exchangeRate;
    f_analysis1_final = f_analysis1;
    f_analysis2_final = f_analysis2;
    f_analysis3_final = f_analysis3;
    f_amount_final = f_amount;
    f_amount2_final = f_amount2;
END;
ELSE DO;
    IF s_chemicalComponent NE '' THEN 
        s_chemicalComponent_final = CATX(',', s_chemicalComponent_final, s_chemicalComponent);
    IF f_basePriceInCurrency NE '' THEN 
        f_basePriceInCurrency_final = CATX(',', f_basePriceInCurrency_final, f_basePriceInCurrency);
    IF s_zzCurrency NE '' THEN 
        s_zzCurrency_final = CATX(',', s_zzCurrency_final, s_zzCurrency);
    IF f_exchangeRate NE '' THEN 
        f_exchangeRate_final = CATX(',', f_exchangeRate_final, f_exchangeRate);
    IF f_analysis1 NE '' THEN 
        f_analysis1_final = CATX(',', f_analysis1_final, f_analysis1);
    IF f_analysis2 NE '' THEN 
        f_analysis2_final = CATX(',', f_analysis2_final, f_analysis2);
    IF f_analysis3 NE '' THEN 
        f_analysis3_final = CATX(',', f_analysis3_final, f_analysis3);
    IF f_amount NE '' THEN 
        f_amount_final = CATX(',', f_amount_final, f_amount);
    IF f_amount2 NE '' THEN 
        f_amount2_final = CATX(',', f_amount2_final, f_amount2);
END;

IF LAST.EBELP THEN OUTPUT;
KEEP EBELN EBELP s_chemicalComponent_final f_basePriceInCurrency_final s_zzCurrency_final 
     f_exchangeRate_final f_analysis1_final f_analysis2_final f_analysis3_final 
     f_amount_final f_amount2_final;
RUN;

PROC SQL;

CREATE TABLE sourcing.sap_spend AS

SELECT
    CATS(INPUT(vbfa.VBELV, 10.)) AS s_soNum,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbfa.VBELN END) AS s_poNumSourcing,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN vbfa.VBELN END) AS s_poNumMill,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN CATS(INPUT(ekpo.EBELP, 10.)) END) AS s_poItemSourcing,
 	MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN CATS(INPUT(ekpo.EBELP, 10.)) END) AS s_poItemMill,
    /* Replace s_soItem "." with s_poItem if necessary */
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN
        CASE 
            WHEN CATS(INPUT(vbap.POSNR, 10.)) = '.' THEN CATS(INPUT(ekpo.EBELP, 10.))
            ELSE CATS(INPUT(vbap.POSNR, 10.))
        END
    END) AS s_soItem,


    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.LIFNR END) AS s_supplierCode,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN lfa1.NAME1 END) AS s_supplierName,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN lfa1.LAND1 END) AS s_supplierCountry,
	MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbak.ERNAM END) AS s_createdBy,
	MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbak.AUART END) AS s_salesDocumentType,
	MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN ekpo.ADRN2 END) AS s_deliveryAddress,
	

	MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.INCO1 END) AS s_incoterms1sourcing,
	MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.INCO2 END) AS s_incoterms2sourcing,
	MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN ekko.INCO1 END) AS s_incoterms1mill,
	MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN ekko.INCO2 END) AS s_incoterms2mill,
	MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.KONNR END) AS s_numPrincipalPurchaseAgreement,

    MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN ekpo.BUKRS END) AS s_millCode,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN ekpo.WERKS END) AS s_plantCode,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' THEN ekpo.LGORT END) AS s_storLocCode,


  /* Concatenated fields from ZTEKPO - properly aggregated */
    MAX(ztc.s_chemicalComponent_final) AS s_zChemicalComponent,
    MAX(ztc.f_basePriceInCurrency_final) AS f_zBasePriceInCurrency,
    MAX(ztc.s_zzCurrency_final) AS s_zCurrency,
    MAX(ztc.f_exchangeRate_final) AS f_zExchangeRate,
    MAX(ztc.f_analysis1_final) AS f_zAnalysis1,
    MAX(ztc.f_analysis2_final) AS f_zAnalysis2,
    MAX(ztc.f_analysis3_final) AS f_zAnalysis3,
    MAX(ztc.f_amount_final) AS f_zAmount,
    MAX(ztc.f_amount2_final) AS f_zAmount2,


    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.MATNR END) AS s_materialCode,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.TXZ01 END) AS s_materialText,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.WKURS END) AS f_fxRate,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.BSART END) AS s_docType,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.MENGE END) AS f_orderQty,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN eket.MENGE END) AS f_scheduleQty,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN eket.WEMNG END) AS f_grQty,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.NETPR END) AS f_netPrice,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.NETWR END) AS f_orderVal,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.WAERS END) AS s_currency,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekko.ZTERM END) AS s_paymentTerm,

    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN (ekko.AEDAT) END) AS d_createOrderDate ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN (ekko.BEDAT) END) AS d_poDocDate ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN (eket.EINDT) END) AS d_scheduleDeliveryDate ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN ekpo.ELIKZ END) AS s_deliveryCompletedFlag,

    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN (ekbe.BUDAT)  END) AS d_postingDate ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN (ekbe.BLDAT)  END) AS d_documentDate ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN (ekbe.CPUDT) END) AS d_entryDate ,


    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '1' AND ekbe.DMBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
            ELSE 0
        END
        ELSE 0
    END) AS f_poHistoryAmountLoc1, /* Total Goods Receipt Amount */

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' AND ekbe.DMBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
            ELSE 0
        END
        ELSE 0
    END) AS f_poHistoryAmountLoc2, /* Total Invoice Receipt Amount */

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '3' AND ekbe.DMBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
            ELSE 0
        END
        ELSE 0
    END) AS f_poHistoryAmountLoc3, /* Total Debit/Credit Note Amount */

    /*SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '4' AND ekbe.DMBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
            ELSE 0
        END
        ELSE 0
    END) AS total_4_DMBTR_amount,

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND TRIM(ekbe.VGABE) = 'C' AND ekbe.DMBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
            ELSE 0
        END
        ELSE 0
    END) AS total_C_DMBTR_amount,*/

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '1' AND ekbe.WRBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.WRBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.WRBTR
            ELSE 0
        END
        ELSE 0
    END) AS f_poHistoryAmountDoc1, /* Total Goods Receipt Value */

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' AND ekbe.WRBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.WRBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.WRBTR
            ELSE 0
        END
        ELSE 0
    END) AS f_poHistoryAmountDoc2, /* Total Invoice Receipt Value */

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '3' AND ekbe.WRBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.WRBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.WRBTR
            ELSE 0
        END
        ELSE 0
    END) AS f_poHistoryAmountDoc3,

   /* SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '4' AND ekbe.WRBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.WRBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.WRBTR
            ELSE 0
        END
        ELSE 0
    END) AS total_4_WRBTR_amount,

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND TRIM(ekbe.VGABE) = 'C' AND ekbe.WRBTR IS NOT NULL THEN
        CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.WRBTR
            WHEN ekbe.SHKZG = 'H' THEN -ekbe.WRBTR
            ELSE 0
        END
        ELSE 0
    END) AS total_C_WRBTR_amount,*/

	MAX(ekbe.WAERS) AS s_poHistoryDocCurrency, /* Currency for WRBTR */

    CASE  /* Calculate final value amount based on GR/IR */
         WHEN SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' AND ekbe.WRBTR IS NOT NULL THEN
             CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
                  WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
                  ELSE 0
             END
             ELSE 0
         END) = 0
         THEN SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '1' AND ekbe.WRBTR IS NOT NULL THEN
             CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
                  WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
                  ELSE 0
             END
             ELSE 0
         END)
         ELSE SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' AND ekbe.WRBTR IS NOT NULL THEN
             CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
                  WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
                  ELSE 0
             END
             ELSE 0
         END) + SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '3' AND ekbe.WRBTR IS NOT NULL THEN
             CASE WHEN ekbe.SHKZG = 'S' THEN ekbe.DMBTR
                  WHEN ekbe.SHKZG = 'H' THEN -ekbe.DMBTR
                  ELSE 0
             END
             ELSE 0
         END)
    END AS f_calculatedPoHistoryFinalAmount,

    SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '1' AND ekbe.MENGE IS NOT NULL THEN
		CASE WHEN ekbe.SHKZG="S" THEN ekbe.MENGE
			 WHEN ekbe.SHKZG="H" THEN -ekbe.MENGE
			 ELSE 0
	END
	ELSE 0
	END) AS f_poHistoryQty1, /* Total Goods Receipt Quantity */
	
	SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' AND ekbe.MENGE IS NOT NULL THEN
		CASE WHEN ekbe.SHKZG="S" THEN ekbe.MENGE
			 WHEN ekbe.SHKZG="H" THEN -ekbe.MENGE
			 ELSE 0
	END
	ELSE 0
	END) AS f_poHistoryQty2, /* Total Invoice Receipt Quantity */

	SUM(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '3' AND ekbe.MENGE IS NOT NULL THEN
		CASE WHEN ekbe.SHKZG="S" THEN ekbe.MENGE
			 WHEN ekbe.SHKZG="H" THEN -ekbe.MENGE
			 ELSE 0
	END
	ELSE 0
	END) AS f_poHistoryQty3, /* Total Debit/Credit Note Quantity */

    /* CPUDT contains the date at which GR/IR accounting documents were received (e.g. invoice). MAX will output the most recent dates */
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '1' THEN (ekbe.CPUDT)  END) AS d_poHistoryEntryDate1 ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' THEN (ekbe.CPUDT)  END) AS d_poHistoryEntryDate2 ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '3' THEN (ekbe.CPUDT)  END) AS d_poHistoryEntryDate3 ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '1' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateSourcingDate1 ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '2' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateSourcingDate2 ,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '3' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateSourcingDate3 ,
   /* MAX(CASE WHEN ekpo.BUKRS = '10H2' AND ekbe.VGABE = '4' THEN (ekbe.CPUDT)  END) AS d4_sourcing_CPUDT,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' AND TRIM(ekbe.VGABE) = 'C' THEN (ekbe.CPUDT) END) AS dc_sourcing_CPUDT,*/

    MIN(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '1' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateMillMinDate1 ,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '1' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateMillMaxDate1 ,

    MIN(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '2' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateMillMinDate2 ,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '2' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateMillMaxDate2 ,

    MIN(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '3' THEN (ekbe.BUDAT)  END) AS d_poHistoryPostDateMillMinDate3 ,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '3' THEN (ekbe.BUDAT) END) AS d_poHistoryPostDateMillMaxDate3 ,

    /*MIN(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '4' THEN (ekbe.BUDAT)  END) AS d4_mill_min ,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' AND ekbe.VGABE = '4' THEN (ekbe.BUDAT)  END) AS d4_mill_max ,

    MIN(CASE WHEN ekpo.BUKRS <> '10H2' AND TRIM(ekbe.VGABE) = 'C' THEN (ekbe.BUDAT)  END) AS dc_mill_min ,
    MAX(CASE WHEN ekpo.BUKRS <> '10H2' AND TRIM(ekbe.VGABE) = 'C' THEN (ekbe.BUDAT)  END) AS dc_mill_max,*/


    /* Origin and VAT data */
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbap.ZZORIGIN_COUNTRY END) AS s_materialOrigin,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbap.ZZDISP_COUNTRY END) AS s_materialOriginDispatch,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbap.ZZKVGR1 END) AS s_vatTypeSO,
    MAX(CASE WHEN ekpo.BUKRS = '10H2' THEN vbap.ZZKVGR1_PURCH END) AS s_vatTypePO,
    MAX(ekpo.loekz) as s_deletionIndicator, /* Deletion indicator in purchasing document item */


	/* BSEG Fields */
	MAX(CASE WHEN bseg.BUKRS = '10H2' THEN bseg.AUGDT END) AS d_clearingDate,
	MAX(CASE WHEN bseg.BUKRS = '10H2' THEN bseg.SGTXT END) AS s_accountingText,
	MAX(CASE WHEN bseg.BUKRS = '10H2' THEN bseg.AUGBL END) AS s_accountingDoc,
	MAX(CASE WHEN bseg.BUKRS = '10H2' THEN bkpf.blart END) AS s_documentType

FROM hana.VBFA AS vbfa  /* Sales Document Flow */

LEFT JOIN hana.EKPO AS ekpo  /* Purchasing Document Item */
    ON ekpo.EBELN = vbfa.VBELN and CATS(INPUT(ekpo.EBELP, 10.)) = CATS(INPUT(vbfa.POSNN, 10.)) and (ekpo.loekz IS NULL OR TRIM(ekpo.loekz) = '')

LEFT JOIN hana.EKKO AS ekko /* Purchasing Document Header */
    ON ekko.EBELN = vbfa.VBELN

LEFT JOIN hana.VBAP AS vbap  /* Sales Document Item Data */
    ON vbap.VBELN = vbfa.VBELV AND %formatCol(vbfa.POSNV) = %formatCol(vbap.POSNR)

LEFT JOIN hana.EKET AS eket  /* Scheduling Agreement Schedule Lines */
    ON eket.EBELN = ekko.EBELN AND eket.EBELP = ekpo.EBELP

LEFT JOIN hana.EKBE AS ekbe  /* History of Purchasing Documents */
    ON ekbe.EBELN = vbfa.VBELN AND ekbe.EBELP = ekpo.EBELP

LEFT JOIN hana.VBAK AS vbak  /* Sales Document Header */
    ON vbak.VBELN = vbfa.VBELV

LEFT JOIN hana.LFA1 AS lfa1 /* Vendor Master General Section */
    ON lfa1.LIFNR = ekko.LIFNR

LEFT JOIN ztekpo_final AS ztc /* Pre-aggregated ZTEKPO data */
    ON ztc.EBELN = vbfa.VBELN AND ztc.EBELP = ekpo.EBELP

LEFT JOIN hana.BSEG AS bseg
           ON  ekbe.belnr = bseg.belnr
           AND ekbe.gjahr = bseg.gjahr
           AND INPUT(ekbe.BUZEI, 8.) = INPUT(bseg.BUZEI, 8.) 
           AND bseg.bukrs = '10H2'
LEFT JOIN hana.BKPF AS bkpf
           ON  bseg.belnr = bkpf.belnr
           AND bseg.gjahr = bkpf.gjahr	

WHERE
    vbfa.VBTYP_N = 'V'
    AND vbfa.VBTYP_V = 'C'
/*	AND vbfa.VBELV = '00000' || '42712' || '44234' */
    AND (
        ekpo.BUKRS = '10H2'
        OR (
            ekpo.BUKRS IN ('1003', '1014', '1015')
            AND ekko.LIFNR = 'AC223678'
        )
     )
    AND (TRIM(PUT(ekbe.VGABE,$1.)) IN ('1', '2', '3', '4', 'C'))
GROUP BY vbfa.VBELV, vbap.POSNR

HAVING
    MAX(
      CASE 
        WHEN ekpo.BUKRS='10H2' THEN ekbe.BLDAT 
        ELSE '' 
      END
    ) > '20151231'
;

;
/* Clean up temporary datasets */
PROC DATASETS LIBRARY=WORK NOLIST;
DELETE ztekpo_concat ztekpo_final;
QUIT;
