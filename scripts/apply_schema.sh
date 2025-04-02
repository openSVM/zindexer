#!/bin/bash

# Default database type is ClickHouse
DB_TYPE="${DB_TYPE:-clickhouse}"

# Use provided database URLs or default to localhost
CLICKHOUSE_URL="${CLICKHOUSE_URL:-http://localhost:8123}"
QUESTDB_URL="${QUESTDB_URL:-http://localhost:9000}"

# Function to format SQL statement
format_sql() {
    local sql=$1
    
    # Remove comments and empty lines
    sql=$(echo "$sql" | grep -v '^--' | grep -v '^$')
    
    # Remove extra spaces
    sql=$(echo "$sql" | tr -s ' ')
    
    # Fix spacing around keywords and operators
    sql=$(echo "$sql" | sed 's/ = /=/g')
    sql=$(echo "$sql" | sed 's/,/ ,/g')
    sql=$(echo "$sql" | sed 's/( /(/g')
    sql=$(echo "$sql" | sed 's/ )/)/g')
    
    # Remove newlines
    sql=$(echo "$sql" | tr '\n' ' ')
    
    echo "$sql"
}

# Function to execute a single SQL statement
execute_sql() {
    local sql=$1
    echo "Executing SQL statement..."
    
    # Format the SQL
    sql=$(format_sql "$sql")
    echo "Formatted SQL: ${sql:0:100}..."
    
    if [ "$DB_TYPE" = "clickhouse" ]; then
        # Execute the SQL for ClickHouse
        local response=$(curl -s -X POST "${CLICKHOUSE_URL}" \
            -H "Content-Type: text/plain" \
            --data-binary "$sql")
        
        local status=$?
        if [ $status -ne 0 ] || [ -n "$response" ]; then
            echo "Failed to execute SQL statement on ClickHouse"
            echo "Error response: $response"
            return 1
        fi
    elif [ "$DB_TYPE" = "questdb" ]; then
        # Execute the SQL for QuestDB
        local response=$(curl -s -X POST "${QUESTDB_URL}/exec" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"$sql\"}")
        
        local status=$?
        if [ $status -ne 0 ] || [[ "$response" == *"error"* ]]; then
            echo "Failed to execute SQL statement on QuestDB"
            echo "Error response: $response"
            return 1
        fi
    else
        echo "Unsupported database type: $DB_TYPE"
        return 1
    fi
    echo
}

# Function to execute SQL file
execute_sql_file() {
    local file=$1
    echo "Applying $file..."
    
    # Read file content
    local content=$(cat "$file")
    
    # Split into individual CREATE TABLE statements and execute each one
    local current_statement=""
    local in_statement=false
    local paren_count=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^--.*$ ]]; then
            continue
        fi
        
        # Check if we're starting a new CREATE TABLE statement
        if [[ "$line" =~ ^CREATE[[:space:]]+TABLE ]]; then
            in_statement=true
            current_statement=""
        fi
        
        if [ "$in_statement" = true ]; then
            # Add line to current statement
            current_statement+="$line"$'\n'
            
            # Count opening parentheses
            paren_count=$((paren_count + $(echo "$line" | grep -o "(" | wc -l)))
            # Count closing parentheses
            paren_count=$((paren_count - $(echo "$line" | grep -o ")" | wc -l)))
            
            # If we've closed all parentheses and found a semicolon, execute the statement
            if [ $paren_count -eq 0 ] && [[ "$line" =~ .*\;$ ]]; then
                if ! execute_sql "$current_statement"; then
                    echo "Failed to apply $file"
                    return 1
                fi
                in_statement=false
                current_statement=""
            fi
        fi
    done < "$file"
    
    echo "Successfully applied $file"
    echo
}

# Apply schema files in order based on database type
if [ "$DB_TYPE" = "clickhouse" ]; then
    echo "Applying ClickHouse schema..."
    for schema_file in \
        "clickhouse/schema/01_core.sql" \
        "clickhouse/schema/02_tokens.sql" \
        "clickhouse/schema/03_defi.sql" \
        "clickhouse/schema/04_analytics.sql" \
        "clickhouse/schema/05_nft_and_security.sql"
    do
        execute_sql_file "$schema_file"
    done
elif [ "$DB_TYPE" = "questdb" ]; then
    echo "Applying QuestDB schema..."
    for schema_file in \
        "questdb/schema/01_core.sql" \
        "questdb/schema/02_tokens.sql" \
        "questdb/schema/03_defi.sql" \
        "questdb/schema/04_analytics.sql" \
        "questdb/schema/05_nft_and_security.sql"
    do
        execute_sql_file "$schema_file"
    done
else
    echo "Unsupported database type: $DB_TYPE"
    exit 1
fi

echo "Schema application complete!"
