#!/bin/bash

# --- Configuration ---
INPUT_DIR="../data-use"
PORECHOP_OUT="porechop-out"
CHOPPER_OUT="chopper-out"
EMU_OUT="emu-out"
EMU_DB="../4-emu-taxonomy/emu_db_silva"
THREADS=18

# Get the list of files
files=("$INPUT_DIR"/*.fastq.gz)

echo ""
echo "Phase 1: Porechop Adapter Trimming and Chopper Quality Filtering"
echo ""

for filepath in "${files[@]}"; do
    # Extract filename without path
    filename=$(basename "$filepath")
    # Base name for output (removes .R1.fastq.gz specifically)
    base_name="${filename%.R1.fastq.gz}"
    
    # 1. Porechop 
    echo ""
    echo "🧑‍🚒 Beginning Porechop adapter trimming on $base_name..."
    echo ""
    porechop -i "$filepath" -o "$PORECHOP_OUT/${base_name}.fastq.gz" --threads "$THREADS"
    echo ""
    echo "🚒 Adapter trimming completed!" 

    # 2. Gunzip
    echo ""
    echo "🧑‍🚒 Unzipping $base_name..."
    echo ""
    gunzip -f "$PORECHOP_OUT/${base_name}.fastq.gz"
    echo ""
    echo "🚒 Unzipping completed!" 
    
    # 3. Chopper
    echo ""
    echo "🧑‍🚒 Beginning Chopper quality trimming on $base_name..."
    echo ""
    cat "$PORECHOP_OUT/${base_name}.fastq" | chopper -q 20 > "$CHOPPER_OUT/${base_name}_trimmed.fastq"
    echo ""
    echo "🚒 Quality filtering completed!" 
done

echo ""
echo "------------------------------------------"
echo "ALL INITIAL PROCESSING COMPLETED"
echo "------------------------------------------"

# Start Phase 2: Emu Abundance
echo ""
echo "Phase 1: Emu Abundance"

# Initialize Conda for the script
source /home/pwoods/miniconda3/etc/profile.d/conda.sh
conda activate py37

for filepath in "${files[@]}"; do
    filename=$(basename "$filepath")
    base_name="${filename%.R1.fastq.gz}"
    
    # Define the input from the chopper-out directory
    chopper_file="$CHOPPER_OUT/${base_name}_trimmed.fastq"

    if [ -f "$chopper_file" ]; then
        echo ""
        echo "🧑‍🚒 Beginning Emu abundance on $base_name..."
        
        emu abundance "$chopper_file" \
            --db "$EMU_DB" \
            --type map-ont \
            --threads "$THREADS" \
            --output-dir "$EMU_OUT" \
            --output-basename "$base_name" \
            --keep-counts
    else
        echo "🔥 Warning: Trimmed file $chopper_file not found!"
    fi
done

conda deactivate

echo ""
echo "---🤺 Pipeline Finished 🤺---"