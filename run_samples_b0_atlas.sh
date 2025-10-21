#!/bin/bash

CUR_DIR=${PWD}
ATLAS_DIR="${CUR_DIR}/b0_atlas"
ROIS_DIR="${ATLAS_DIR}/rois"

B0_TEMPLATE="${ATLAS_DIR}/b0_template.nii.gz"
DSI_STUDIO="/home/filipp02/local/dsi-studio/dsi_studio"

HEMISPHERES="l r"

TRACT_COUNT=100
TIP_ITERATION=0
THRESH_INDEX="qa"
TRACKING_THRESH="0.02" # "0.01"

while (( "${#}" ))
do

	case ${1} in
	
		-register)
			RUN_REGISTER=1
			;;
		-tracking)
			RUN_TRACKING=1
			;;
		-l)
			HEMISPHERES="l"
			;;
		-r)
			HEMISPHERES="r"
			;;
		-thresh)
			TRACKING_THRESH=${2}
			shift
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
	OUTPUT_DIR="${PWD}/register_atlas"

	if [ ! -d "${OUTPUT_DIR}" ]
	then
		mkdir ${OUTPUT_DIR}
	fi

	dwiextract -bzero -fslgrad dwi/dwi_designer.bvec dwi/dwi_designer.bval \
		dwi/dwi_designer.nii.gz - | mrmath -force - mean ${OUTPUT_DIR}/b0.nii.gz -axis 3

	mrtransform -force ${SUBJECT}_${SESSION}_T1w.nii.gz \
		-template ${OUTPUT_DIR}/b0.nii.gz ${OUTPUT_DIR}/t1.nii.gz

	if [ ${RUN_REGISTER} ] 
	then
		antsRegistrationSyN.sh -d 3 -t s -f ${B0_TEMPLATE} \
			-m ${OUTPUT_DIR}/b0.nii.gz -o ${OUTPUT_DIR}/b0_mni
	fi

	# Create an empty mask
	fslmaths ${OUTPUT_DIR}/b0.nii.gz -thr 0 -uthr 0 ${OUTPUT_DIR}/b0_empty.nii.gz

	for HEMISPHERE in ${HEMISPHERES}
	do

		# Convert the ROI coordinates (physical, LPS) from the MNI space to the scanner space
		antsApplyTransformsToPoints \
			-i ${ROIS_DIR}/rois_${HEMISPHERE}_lps.csv -d 3 \
			-t ${OUTPUT_DIR}/b0_mni0GenericAffine.mat ${OUTPUT_DIR}/b0_mni1Warp.nii.gz \
			-o ${OUTPUT_DIR}/rois_${HEMISPHERE}_lps_warped.csv

		COORDS_LIST=`cat ${OUTPUT_DIR}/rois_${HEMISPHERE}_lps_warped.csv | cut -f1-3,5 -d',' | tail -n +2`

		for COORDS in ${COORDS_LIST}
		do
			COORD_X_LPS=`echo ${COORDS} | cut -f1 -d','`
			COORD_Y_LPS=`echo ${COORDS} | cut -f2 -d','`
			COORD_Z_LPS=`echo ${COORDS} | cut -f3 -d','`

			COORD_X_RAS=`echo "-1*${COORD_X_LPS}" | bc`
			COORD_Y_RAS=`echo "-1*${COORD_Y_LPS}" | bc`
			COORD_Z_RAS=${COORD_Z_LPS}

			ROI_ID=`echo ${COORDS} | cut -f4 -d','`
			ROI_LABEL=$(printf '%s_%02d' "${HEMISPHERE}" "${ROI_ID}")
			
			mredit ${OUTPUT_DIR}/b0_empty.nii.gz -force \
				-scanner -voxel ${COORD_X_RAS},${COORD_Y_RAS},${COORD_Z_RAS} 1 \
				${OUTPUT_DIR}/roi_b0_${ROI_LABEL}.nii.gz

		done

	done


	for TRACKING_ROI in "optic_chiasm" "globe_l" "globe_r"
	do
		antsApplyTransforms -i ${ROIS_DIR}/${TRACKING_ROI}.nii.gz -d 3 \
			-t [ ${OUTPUT_DIR}/b0_mni0GenericAffine.mat, 1 ] ${OUTPUT_DIR}/b0_mni1InverseWarp.nii.gz \
			-r ${OUTPUT_DIR}/b0.nii.gz -o ${OUTPUT_DIR}/tracking_roi_${TRACKING_ROI}.nii.gz
			
		fslmaths ${OUTPUT_DIR}/tracking_roi_${TRACKING_ROI}.nii.gz -thr 0.5 -bin -dilM -dilM -dilM -dilM -dilM \
			${OUTPUT_DIR}/tracking_roi_${TRACKING_ROI}_bin.nii.gz
	done
	
	fslmaths dwi/params/md_dti.nii -thr 2 -bin -mas ${OUTPUT_DIR}/tracking_roi_globe_l_bin.nii.gz -dilM \
		${OUTPUT_DIR}/tracking_roi_globe_l_masked.nii.gz
		
	fslmaths dwi/params/md_dti.nii -thr 2 -bin -mas ${OUTPUT_DIR}/tracking_roi_globe_r_bin.nii.gz -dilM \
		${OUTPUT_DIR}/tracking_roi_globe_r_masked.nii.gz
		
	fslmaths dwi/params/md_dti.nii -thr 2 -bin -mas ${OUTPUT_DIR}/tracking_roi_optic_chiasm_bin.nii.gz \
		${OUTPUT_DIR}/tracking_roi_optic_chiasm_masked.nii.gz
	
	fslmaths dwi/params/mk_dki.nii.gz -thr 3 -bin ${OUTPUT_DIR}/mk_dki_thr3_bin.nii.gz
	
#	dwi2response tournier -force -fslgrad dwi/dwi_designer.bvec dwi/dwi_designer.bval dwi/dwi_designer.nii.gz dwi/response_wm.txt
#	dwi2fod csd -force -fslgrad dwi/dwi_designer.bvec dwi/dwi_designer.bval dwi/dwi_designer.nii.gz dwi/response_wm.txt dwi/wmfod.mif
	
#	5ttgen fsl -nocrop -force ${OUTPUT_DIR}/t1.nii.gz ${OUTPUT_DIR}/5tt.nii.gz
#	mrconvert -force ${OUTPUT_DIR}/5tt.nii.gz -coord 3 2:3 ${OUTPUT_DIR}/5tt_wm.nii.gz
#	fslmaths ${OUTPUT_DIR}/5tt_wm.nii.gz -thr 1 -bin ${OUTPUT_DIR}/5tt_wm_bin.nii.gz

	if [ ${RUN_TRACKING} ] 
	then

		if [ ! -f dwi/*.fib.gz ]
		then 
			${DSI_STUDIO} --action=src --source=dwi/dwi_designer.nii.gz \
				--bvec=dwi/dwi_designer.bvec --bval=dwi/dwi_designer.bval
				
			${DSI_STUDIO} --action=rec --source=dwi/*.src.gz --method=4 --param0=1.25 \
				--mask=dwi/processing/brain_mask_dilated.nii --output=dwi/
		fi
	
		for HEMISPHERE in ${HEMISPHERES}
		do
	#		tckgen -force -algorithm SD_STREAM dwi/wmfod.mif ${OUTPUT_DIR}/tracks_${HEMISPHERE}.tck \
	#			-seed_image ${OUTPUT_DIR}/tracking_roi_optic_chiasm_masked.nii.gz \
	#			-exclude ${OUTPUT_DIR}/mk_dki_thr3_bin.nii.gz \
	#			-exclude ${OUTPUT_DIR}/5tt_wm_bin.nii.gz \
	#			-include ${OUTPUT_DIR}/tracking_roi_globe_${HEMISPHERE}_masked.nii.gz \
	#			-cutoff 0.01 -select 100 -minlength 30 -maxlength 50 -angle 60 -stop
	#
	#		tckmap -force -template dwi/dwi_designer.nii.gz \
	#			${OUTPUT_DIR}/tracks_${HEMISPHERE}.tck ${OUTPUT_DIR}/tdi_${HEMISPHERE}.nii.gz

			${DSI_STUDIO} --action=trk \
				--source=dwi/*.fib.gz \
				--method=0 \
				--fiber_count=${TRACT_COUNT} \
				--seed=${OUTPUT_DIR}/tracking_roi_optic_chiasm_masked.nii.gz \
				--end=${OUTPUT_DIR}/tracking_roi_globe_${HEMISPHERE}_masked.nii.gz \
				--roa=${OUTPUT_DIR}/mk_dki_thr3_bin.nii.gz \
				--tip_iteration=${TIP_ITERATION} \
				--step_size=1 \
				--threshold_index=${THRESH_INDEX} --fa_threshold=${TRACKING_THRESH} \
				--turning_angle=60 \
				--min_length=30 --max_length=50 \
				--export=tdi,stat \
				--output=${OUTPUT_DIR}/track_${HEMISPHERE}.tt.gz # > /dev/null 2> /dev/null

			SRC_FILE="${OUTPUT_DIR}/track_${HEMISPHERE}.tt.gz.tdi.nii.gz"
			REF_FILE="${OUTPUT_DIR}/b0.nii.gz"

			REF_STRIDES=`mrinfo -strides ${REF_FILE} | sed 's/ /,/g' | cut -f1-3 -d ","`

			mrconvert ${SRC_FILE} -strides ${REF_STRIDES} - | \
			    mrtransform -force - -replace ${REF_FILE} ${SRC_FILE}

		done	

	fi	
	
	cd ${SUBJECT_DIR}
done

rm -rf ${OUTPUT_DIR}/b0_empty.nii.gz


