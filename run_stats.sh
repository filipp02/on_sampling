#!/bin/bash

CUR_DIR=${PWD}
ROIS_PREFIX=""
REGISTER_TYPE="register"

# --- Parse the input parameters

while (( "${#}" ))
do

    case ${1} in

        -rois)
            RUN_ROIS=1
            ;;

        -dti)
            RUN_DTI=1
            ;;

        -dki)
            RUN_DKI=1
            ;;

        -smi)
            RUN_SMI=1
            ;;

        -noddi)
            RUN_NODDI=1
            ;;

        -site)
            RUN_SITE=1
            ;;

        -all)
            RUN_ALL=1
            ;;

        -t1)
            ROIS_PREFIX="t1_"
            ;;

        -atlas)
            REGISTER_TYPE="register_atlas"
            ROIS_PREFIX="b0_"
            ;;

        -proj)
            REGISTER_TYPE="register_atlas"
            ROIS_PREFIX="b0_proj_"
            ;;

        *)
            SUBJECT=${1}
            ;;

    esac
    shift

done

cd ${SUBJECT}
SUBJECT_DIR=${PWD}

for SESSION in ses-*
do

    cd ${SESSION}
    SESSION_DIR=${PWD}

    DATA_DIR="${SESSION_DIR}/${REGISTER_TYPE}"
    DWI_DIR="${SESSION_DIR}/dwi"
    ROIS_BACKUP_DIR="${DATA_DIR}/rois_backup"

    cd ${DATA_DIR}

    if [ ${RUN_ROIS} ] || [ ${RUN_ALL} ]
    then

        DWI_STRIDES=`mrinfo -strides b0.nii.gz | sed 's/ /,/g'`

        if [ ! -f ${ROIS_BACKUP_DIR} ]
        then
            mkdir ${ROIS_BACKUP_DIR}
        fi

        for FILE in roi_${ROIS_PREFIX}?_??.nii.gz
        do
            fslstats ${FILE} -V
        done

        for HEMISPHERE in "l" "r"
        do

            for ROI in 00 01 02 03 04 05 06 07 08 09 10 11
            do
                mrconvert roi_${ROIS_PREFIX}${HEMISPHERE}_${ROI}.nii.gz -strides ${DWI_STRIDES} - | \
                    mrtransform -force - -replace b0.nii.gz roi_${ROIS_PREFIX}${HEMISPHERE}_${ROI}.nii.gz
                maskfilter -force roi_${ROIS_PREFIX}${HEMISPHERE}_${ROI}.nii.gz dilate -npass 1 roi_${ROIS_PREFIX}${HEMISPHERE}_${ROI}_dilm.nii.gz
                cp roi_${ROIS_PREFIX}${HEMISPHERE}_${ROI}.nii.gz roi_${ROIS_PREFIX}${HEMISPHERE}_${ROI}_dilm.nii.gz ${ROIS_BACKUP_DIR}
            done

        done

    fi


    # --- DTI metrics ---

    if [ ${RUN_DTI} ] || [ ${RUN_ALL} ]
    then

        for METRIC in "fa" "md" "ad" "rd"
        do

            echo "=== ${METRIC} ==="
            METRIC_IMG="${DWI_DIR}/params/${METRIC}_dti.nii"
            METRIC_OUTPUT="stat_${ROIS_PREFIX}${METRIC}.csv"
            METRIC_OUTPUT_DILM="stat_${ROIS_PREFIX}${METRIC}_dilm.csv"

            echo -e "${METRIC}_l\t${METRIC}_r" > ${METRIC_OUTPUT}
            cp ${METRIC_OUTPUT} ${METRIC_OUTPUT_DILM}

            for ROI in 00 01 02 03 04 05 06 07 08 09 10 11
            do

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}.nii.gz tmp.nii.gz
                VALUE_L=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}.nii.gz tmp.nii.gz
                VALUE_R=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L}\t${VALUE_R}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT}

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_L_DILM=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_R_DILM=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L_DILM}\t${VALUE_R_DILM}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT_DILM}

                rm -rf tmp.nii.gz

            done

        done

    fi

    # --- DKI metrics ---

    if [ ${RUN_DKI} ] || [ ${RUN_ALL} ]
    then

        for METRIC in "mk" "ak" "rk"
        do

            echo "=== ${METRIC} ==="
            METRIC_IMG="${DWI_DIR}/params/${METRIC}_dki.nii"
            METRIC_OUTPUT="stat_${ROIS_PREFIX}${METRIC}.csv"
            METRIC_OUTPUT_DILM="stat_${ROIS_PREFIX}${METRIC}_dilm.csv"

            echo -e "${METRIC}_l\t${METRIC}_r" > ${METRIC_OUTPUT}
            cp ${METRIC_OUTPUT} ${METRIC_OUTPUT_DILM}

            for ROI in 00 01 02 03 04 05 06 07 08 09 10 11
            do

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}.nii.gz tmp.nii.gz
                VALUE_L=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}.nii.gz tmp.nii.gz
                VALUE_R=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L}\t${VALUE_R}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT}

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_L_DILM=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_R_DILM=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L_DILM}\t${VALUE_R_DILM}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT_DILM}

                rm -rf tmp.nii.gz

            done

        done

    fi

    # --- SMI metrics ---

    if [ ${RUN_SMI} ] || [ ${RUN_ALL} ]
    then

        for METRIC in "Da" "DePar" "DePerp" "f" "fw"
        do

            echo "=== ${METRIC} ==="
            METRIC_IMG="${DWI_DIR}/params/${METRIC}_smi.nii"
            METRIC_OUTPUT="stat_${ROIS_PREFIX}${METRIC}.csv"
            METRIC_OUTPUT_DILM="stat_${ROIS_PREFIX}${METRIC}_dilm.csv"

            echo -e "${METRIC}_l\t${METRIC}_r" > ${METRIC_OUTPUT}
            cp ${METRIC_OUTPUT} ${METRIC_OUTPUT_DILM}

            for ROI in 00 01 02 03 04 05 06 07 08 09 10 11
            do

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}.nii.gz tmp.nii.gz
                VALUE_L=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}.nii.gz tmp.nii.gz
                VALUE_R=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L}\t${VALUE_R}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT}

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_L_DILM=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_R_DILM=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L_DILM}\t${VALUE_R_DILM}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT_DILM}

                rm -rf tmp.nii.gz

            done

        done

    fi

    # --- NODDI ---

    if [ ${RUN_NODDI} ] || [ ${RUN_ALL} ]
    then

        for SOLVER in "brute2fine_ns30_nss90" # "mix"
        do

            for METRIC in "ndi" "odi" "p_iso"
            do

                echo "=== ${METRIC} ==="
                METRIC_IMG="${DWI_DIR}/params/noddi_watson.${SOLVER}_${METRIC}.nii.gz"
                METRIC_OUTPUT="stat_${ROIS_PREFIX}noddi_${METRIC}.csv"
                METRIC_OUTPUT_DILM="stat_${ROIS_PREFIX}noddi_${METRIC}_dilm.csv"

                echo -e "${METRIC}_l\t${METRIC}_r" > ${METRIC_OUTPUT}
                cp ${METRIC_OUTPUT} ${METRIC_OUTPUT_DILM}

                for ROI in 00 01 02 03 04 05 06 07 08 09 10 11
                do

                    fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}.nii.gz tmp.nii.gz
                    VALUE_L=`fslstats tmp.nii.gz -n -M`

                    fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}.nii.gz tmp.nii.gz
                    VALUE_R=`fslstats tmp.nii.gz -n -M`

                    echo -e "${VALUE_L}\t${VALUE_R}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT}

                    fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}_dilm.nii.gz tmp.nii.gz
                    VALUE_L_DILM=`fslstats tmp.nii.gz -n -M`

                    fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}_dilm.nii.gz tmp.nii.gz
                    VALUE_R_DILM=`fslstats tmp.nii.gz -n -M`

                    echo -e "${VALUE_L_DILM}\t${VALUE_R_DILM}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT_DILM}

                    rm -rf tmp.nii.gz

                done

            done

        done

    fi
    
    # --- NODDI ---

    if [ ${RUN_SITE} ] || [ ${RUN_ALL} ]
    then

        for METRIC in "odi" "p_1" "p_2" "p_csf"
        do

            echo "=== ${METRIC} ==="
            METRIC_IMG="${DWI_DIR}/params/site_noddi_${METRIC}.nii.gz"
            METRIC_OUTPUT="stat_${ROIS_PREFIX}site_noddi_${METRIC}.csv"
            METRIC_OUTPUT_DILM="stat_${ROIS_PREFIX}site_noddi_${METRIC}_dilm.csv"

            echo -e "${METRIC}_l\t${METRIC}_r" > ${METRIC_OUTPUT}
            cp ${METRIC_OUTPUT} ${METRIC_OUTPUT_DILM}

            for ROI in 00 01 02 03 04 05 06 07 08 09 10 11
            do

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}.nii.gz tmp.nii.gz
                VALUE_L=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}.nii.gz tmp.nii.gz
                VALUE_R=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L}\t${VALUE_R}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT}

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}l_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_L_DILM=`fslstats tmp.nii.gz -n -M`

                fslmaths ${METRIC_IMG} -mas roi_${ROIS_PREFIX}r_${ROI}_dilm.nii.gz tmp.nii.gz
                VALUE_R_DILM=`fslstats tmp.nii.gz -n -M`

                echo -e "${VALUE_L_DILM}\t${VALUE_R_DILM}" | sed 's/ //g' | tee -a ${METRIC_OUTPUT_DILM}

                rm -rf tmp.nii.gz

            done

        done

    fi
    
    cd ${SUBJECT_DIR}
    
done

cd ${CUR_DIR}


