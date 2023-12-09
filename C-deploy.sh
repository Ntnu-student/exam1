#!/bin/bash

# Download the Wikipedia page and save it as wikilist.html
curl -s https://en.wikipedia.org/wiki/List_of_municipalities_of_Norway > wikilist.html

# Process the HTML to extract the table
# Removing new lines, tab characters and save it as wiki.list.no.newlines.html
cat "wikilist.html" | tr -d '\n\t' > wiki.list.no.newlines.html
# Using steam editor (sed) to extract the table content into table.txt
sed -E 's/.*<table class="sortable wikitable">(.*)<\/table>.*/\1/g' wiki.list.no.newlines.html | 
    sed 's/<\/table>/\n/g' | sed -n '1p' | grep -o '<tbody[ >].*<\/tbody>' | 
    sed -E 's/<tbody[^>]*>(.*)<\/tbody>/\1/g' | sed -E 's/<tr[^>]*>//g' | 
    sed 's/<\/tr>/\n/g' | sed -E 's/<td[^>]*>//g' | sed 's/<\/td>/\t/g' | 
    sed '1d' > table.txt

# Column data extraction
# Extract municipality names from the 2nd column
cut -f 2 table.txt > column2.txt
# Extract population data from the 5th column
cut -f 5 table.txt > column5.txt

# Extract municipality URLs from the 2nd column
awk 'match($0, /href="([^"]*)"/){print "https://en.wikipedia.org" substr($0, RSTART+6, RLENGTH-7)}' column2.txt > data.txt

# Extract coordinates from individual municipality URLs
truncate -s 0 coordata.txt 
while read url; do
    pageHtml="$(curl -s "$url")"
    lat=$(echo "$pageHtml" | grep -o '<span class="latitude">[^<]*' | head -n 1 | sed 's/<span class="latitude">//' )
    lon=$(echo "$pageHtml" | grep -o '<span class="longitude">[^<]*' | head -n 1 | sed 's/<span class="longitude">//' )
    printf "%s\t%s\n" "$lat" "$lon" >> coordata.txt
done < data.txt

# Splitting the coordinate data into separate files
awk '{print $1 }' coordata.txt > lat.txt
awk '{print $2 }' coordata.txt > lon.txt

# Removing everything that isn't raw numbers
sed -E 's/[^0-9°′″]/ /g; s/°|′|″/ /g' lat.txt > fix-lat.txt
sed -E 's/[^0-9°′″]/ /g; s/°|′|″/ /g' lon.txt > fix-lon.txt

# Translating the coordinates from degrees to decimal
awk '{
    degrees=$1;
    minutes=$2;
    seconds=$3;
    dec_deg = degrees + (minutes / 60) + (seconds / 3600);
    printf("%.6f\n", dec_deg);
}' fix-lat.txt > decimal-lat.txt
awk '{
    degrees=$1;
    minutes=$2;
    seconds=$3;
    dec_deg = degrees + (minutes / 60) + (seconds / 3600);
    printf("%.6f\n", dec_deg);
}' fix-lon.txt > decimal-lon.txt

# Remove redundant coordinate files that isn't used for the production of the final html file
file1="lat.txt"
file2="lon.txt"
file3="fix-lat.txt"
file4="fix-lon.txt"
file5="coordata.txt"
rm -f "$file1" "$file2" "$file3" "$file4" "$file5"

# Merging the two coordinate parts into one file
paste decimal-lat.txt decimal-lon.txt > merged-coords.txt

# Generate HTML paragraphs with municipality names, coordinates, and population data
paste column2.txt merged-coords.txt column5.txt | awk -F'\t' '{
    if (NF >= 4) {
        printf "<p>%s is located at these coordinates: %s, %s And the population is: %s</p>\n", $1, $2, $3, $4
    }
}' > "data.html"

# Fixing the links by inserting the full wikipedia URL
sed -i 's|/wiki/|https://en.wikipedia.org/wiki/|g' data.html

# HTML template
page_template='
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="style.css">
    <title>Candidate 10045 boring municipalities page</title>
</head>
<body>
    <h1>Candidate 10045 boring municipalities page that 10045 ripped from Wikipedia</h1>
    <!-- Inserting generated data -->
    <!--REPLACEME-->
</body>
</html>
'

# Render the final page by replacing placeholder with generated data
sed -e '/<!--REPLACEME-->/r data.html' -e '/<!--REPLACEME-->/d' <<< "$page_template" > done.html

# Move the finished file and rename it to index.html into www/bing folder and restart apache2 to update the web server.
sudo cp done.html /var/www/bing/index.html 
sudo systemctl restart apache2