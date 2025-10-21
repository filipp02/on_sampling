#!/bin/bash

SUBJECT=${1} # sub-01
CUR_DIR=${PWD}

DESIGNER_DOCKER_IMAGE="nyudiffusionmri/designer2:v2.0.11"

if [ ! -d "${SUBJECT}" ]
then
	mkdir ${SUBJECT}
fi


BIDS_DIR="../bids"

cd ${BIDS_DIR}/${SUBJECT}
BIDS_SUBJECT_DIR="${PWD}"


for SESSION_DIR in ses-*
do
	SMI_SESSION_DIR="${CUR_DIR}/${SUBJECT}/${SESSION_DIR}"
	
	if [ ! -d "${SMI_SESSION_DIR}" ]
	then
		mkdir ${SMI_SESSION_DIR} ${SMI_SESSION_DIR}/dwi
	fi
	 
	cd ${BIDS_SUBJECT_DIR}/${SESSION_DIR}/anat

	cp *T1w.nii.gz ${SMI_SESSION_DIR}
	cp *T2w.nii.gz ${SMI_SESSION_DIR}
	cp *FLAIR.nii.gz ${SMI_SESSION_DIR}
	
	cd ${BIDS_SUBJECT_DIR}/${SESSION_DIR}/dwi

	DWI_AP_FILES=""	
	for DWI_BVAL in *RDSIB4000_dwi.bval 
	do
		DWI_AP_PREFIX=`echo ${DWI_BVAL} | sed 's/.bval//g'`
		cp ${DWI_AP_PREFIX}.* ${SMI_SESSION_DIR}/dwi

		if [ "$DWI_AP_FILES" = "" ]
		then
			DWI_AP_FILES="/dwi/${DWI_AP_PREFIX}.nii.gz"
		else
			DWI_AP_FILES="${DWI_AP_FILES},/dwi/${DWI_AP_PREFIX}.nii.gz"
		fi
	done

	cp *PA* ${SMI_SESSION_DIR}/dwi

	DWI_PA_FILE=`ls *PA*.nii.gz | head -n1`
	DWI_PA_FILE="/dwi/${DWI_PA_FILE}"
	
	cd ${SMI_SESSION_DIR}
	
	docker run --rm --platform linux/x86_64 -it -v "${PWD}/dwi:/dwi" \
		${DESIGNER_DOCKER_IMAGE} designer \
		-denoise \
		-shrinkage frob \
		-adaptive_patch \
		-rician \
		-degibbs \
		-normalize \
		-mask \
		-eddy -rpe_pair ${DWI_PA_FILE} \
		-nocleanup \
		-scratch /dwi/processing \
		${DWI_AP_FILES} \
		/dwi/dwi_designer.nii.gz
		
	maskfilter dwi/processing/brain_mask.nii dilate -npass 20 dwi/processing/brain_mask_dilated.nii -force		
		
	docker run --rm --platform linux/x86_64 -it -v "${PWD}/dwi:/dwi" \
		${DESIGNER_DOCKER_IMAGE} tmi \
		-DTI -DKI -WDKI -SMI \
		-sigma /dwi/processing/sigma.nii \
		-mask /dwi/processing/brain_mask_dilated.nii \
		-fit_constraints 0,0,0 \
		-akc_outliers \
		-fit_smoothing 10 \
		/dwi/dwi_designer.nii.gz \
		/dwi/params

        cd ${BIDS_SUBJECT_DIR}
	
done

cd ${CUR_DIR}

