#!/bin/bash

set -e

echo "::group::Validate inputs"
if [ -z "$1" ]
then
  echo "No allure result dirs argument supplied"
  exit 1
else
  allure_result_dirs=$1
fi

if [ -z "$2" ]
then
  echo "No allure report dir argument supplied"
  exit 1
else
  allure_report_dir=$2
fi

if [ -z "$3" ]
then
  echo "No github pages branch argument supplied"
  exit 1
else
  gh_pages_branch=$3
fi

if [ -z "$4" ]
then
  echo "No build url argument supplied"
  exit 1
else
  build_url=$4
fi

if [ -z "$5" ]
then
  echo "No max history argument supplied"
  exit 1
else
  max_history=$5
fi

if [ -z "$6" ]
then
  echo "No environment argument supplied"
  environment_info=""
else
  environment_info="$6"
fi

source_branch=$(git rev-parse --abbrev-ref HEAD)
echo "Current Git Branch: $source_branch"

echo "::group::Create combined directory and copy reports"
# Split the result paths and store them in an array
IFS=',' read -ra PATHS <<< "$allure_result_dirs"

# Create a directory to collect all results
mkdir -p combined-results

# Copy results from each specified directory to the combined-results directory
for path in "${PATHS[@]}"; do
  echo "Copying results from $path"
  cp -r "$path"/* combined-results/
done

echo "::endgroup::"

echo "::group::Checkout to github pages branch"
# Discard changes in working directory
git checkout -- .
# Checkout to github pages branch
git checkout $gh_pages_branch
echo "::endgroup::"

echo "::group::Prepare executor and environment information"
REPO=${GITHUB_REPOSITORY##*/}
REPORT_DIR=${allure_report_dir#./docs/}
REPORT_DIR=${REPORT_DIR#./docs}
if [ -z "$REPORT_DIR" ]; then
  REPORT_URL="https://$GITHUB_REPOSITORY_OWNER.github.io/$REPO/$RUN_ID"
else
  REPORT_URL="https://$GITHUB_REPOSITORY_OWNER.github.io/$REPO/$REPORT_DIR/$RUN_ID"
fi

# Add executor information
cat <<EOF > "combined-results/executor.json"
{
  "name": "Github",
  "type": "github",
  "buildUrl": "$build_url",
  "reportName": "Allure Report",
  "reportUrl": "$REPORT_URL",
  "buildName": "$GITHUB_WORKFLOW",
  "buildOrder": "$RUN_ID"
}
EOF
echo "executor.json:"
cat "combined-results/executor.json"

# Add environment information
cat <<EOF >> "combined-results/environment.properties"
${environment_info}
EOF

if command -v java &>/dev/null; then
  java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  echo "java_version = $java_version" >> "combined-results/environment.properties"
fi
if command -v python &>/dev/null; then
  python_version=$(python --version 2>&1 | awk '{print $2}')
  echo "python_version = $python_version" >> "combined-results/environment.properties"
fi
if command -v google-chrome &>/dev/null; then
  chrome_version=$(google-chrome --product-version 2>&1)
  echo "chrome_version = $chrome_version" >> "combined-results/environment.properties"
fi
if command -v allure &>/dev/null; then
  allure_version=$(allure --version)
  echo "allure_version = $allure_version" >> "combined-results/environment.properties"
fi

echo "environment.properties:"
cat "combined-results/environment.properties"
echo "::endgroup::"

echo "::group::Copy previous report to allure result to include it to history"
if [ -d "$allure_report_dir/latest/history" ]; then
  cp -r "$allure_report_dir/latest/history" "combined-results/history"
  echo "Copied $allure_report_dir/latest/history to combined-results/history"
fi
echo "::endgroup::"

echo "::group::Generate report"
allure generate "combined-results/" -o "$allure_report_dir/latest" --clean
echo "::endgroup::"

echo "::group::Replace latest report and remove old reports"
# Copy latest to github run number folder
cp -r "$allure_report_dir/latest" "$allure_report_dir/$RUN_ID"

# Filter folders to keep
num_directories=$(find $allure_report_dir/ -mindepth 1 -maxdepth 1 -type d | wc -l)
echo "Number of directories: $num_directories"
if [ $num_directories -ge $((max_history+1)) ]; then
  folders_to_keep=$(cd $allure_report_dir && ls -d */ | sort -t/ -nr | sed "s|^|$allure_report_dir/|" | head -n $max_history)
  folders_to_keep=$"$folders_to_keep\n$allure_report_dir/latest/"
  echo "$folders_to_keep"
  # Remove folders that are not listed in folders_to_keep
  ls -d $allure_report_dir/*/ | grep -vFf <(echo "$folders_to_keep") | grep -v "./latest" | xargs rm -rf
fi
echo "::endgroup::"

echo "::group::Create index.html"
# Create index.html that lists all historical reports
index_file="$allure_report_dir/index.html"
cat <<EOF > "$index_file"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1, width=device-width" />
  <title>${GITHUB_REPOSITORY} - Allure Reports</title>
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: baseline;
      padding-top: 10rem;
    }

    .content {
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
    }


    .styled-table {
      border-collapse: collapse;
      margin: 25px 0;
      font-size: 0.9em;
      font-family: sans-serif;
      min-width: 400px;
      box-shadow: 0 0 20px rgba(0, 0, 0, 0.15);
    }

    .styled-table thead tr {
      background-color: #007EA3;
      color: #ffffff;
      text-align: left;
    }

    .styled-table th,
    .styled-table td {
      padding: 12px 15px;
      text-align: center;
    }

    .styled-table tbody tr {
      border-bottom: 1px solid #dddddd;
    }

    .styled-table tbody tr:nth-of-type(even) {
      background-color: #f3f3f3;
    }

    .styled-table tbody tr:last-of-type {
      border-bottom: 2px solid #007EA3;
    }

    .styled-table tbody tr.active-row {
      font-weight: bold;
      color: #007EA3;
    }

    .button {
      align-items: center;
      background-color: #fff;
      border-radius: 12px;
      box-shadow: transparent 0 0 0 3px, rgba(18, 18, 18, .1) 0 6px 20px;
      box-sizing: border-box;
      color: #121212;
      cursor: pointer;
      display: inline-flex;
      flex: 1 1 auto;
      font-family: Inter, sans-serif;
      font-size: 1.2rem;
      font-weight: 700;
      justify-content: center;
      line-height: 1;
      margin: 0;
      outline: none;
      padding: 1rem 1.2rem;
      text-align: center;
      text-decoration: none;
      transition: box-shadow .2s, -webkit-box-shadow .2s;
      white-space: nowrap;
      border: 0;
      user-select: none;
      -webkit-user-select: none;
      touch-action: manipulation;
    }

    .button:hover {
      box-shadow: #121212 0 0 0 3px, transparent 0 0 0 0;
    }
  </style>
</head>
<body>
  <div class="content">
    <h1>${REPO} Reports</h1>
EOF

if [ -n "$REPORT_DIR" ]; then
  echo "<h2>$REPORT_DIR</h2>" >> "$index_file"
fi

cat <<EOF >> "$index_file"
    <table class="styled-table">
    <thead>
      <tr>
        <th>Report</th>
        <th>Date</th>
      </tr>
    </thead>
    <tbody>
EOF

# Add latest entry to report list
date="$(stat -c %y "$allure_report_dir/latest" | cut -d '.' -f 1)"
echo "<tr><td><a href='./latest/index.html'>latest</a></td><td>$date</td></tr>" >> "$index_file"

# Add other executions entries to report list
for folder in `cd $allure_report_dir && ls -d */ | sort -rn -k1 | grep -v 'latest'`; do
  folder_name=$(basename "$folder")
  date=$(git log -1 --pretty="format:%ci" "$allure_report_dir/$folder")
  if [[ $date == "" ]]; then
    date="$(stat -c %y "$allure_report_dir/$folder_name" | cut -d '.' -f 1)"
    echo "<tr><td><a href='./$folder_name/index.html'>$folder_name</a></td><td>$date</td></tr>" >> "$index_file"
  else
    echo "<tr><td><a href='./$folder_name/index.html'>$folder_name</a></td><td>$date</td></tr>" >> "$index_file"
  fi
done

echo "</tbody></table>" >> "$index_file"


echo "::group::Copy screenshots to Allure report"

# Fetch the latest changes from the source branch
git fetch origin $source_branch

# Check if there are any screenshots in the Results folder
if ls Results/*.png 1> /dev/null 2>&1; then
    mv Results/*.png $allure_report_dir/latest/data/attachments/
else
    echo "No screenshots found in Results folder!"
fi

echo "::endgroup::"


if [ "$ENABLE_MULTIPLE_REPORT_TYPES" == "true" ]; then
  echo "<h2>Other Reports</h2><p>" >> "$index_file"
  current_report=$(basename "$allure_report_dir")
  for report_dir in `ls -d ./docs/*/`; do
    report_name=$(basename "$report_dir")
    if [ "$report_name" != "$current_report" ]; then
      echo "<a href=\"/$report_name/index.html\" class=\"button\">$report_name</a>" >> "$index_file"
    fi
  done
  echo "</p>" >> "$index_file"
fi

echo "</div></body></html>" >> "$index_file"
echo "::endgroup::"

if [ "$ENABLE_MULTIPLE_REPORT_TYPES" == "true" ]; then
  echo "::group::Generate main index.html"
  main_index_file="./docs/index.html"
  cat <<EOF > "$main_index_file"
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1, width=device-width" />
  <title>${GITHUB_REPOSITORY} - Allure Reports</title>
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: baseline;
      padding-top: 10rem;
    }

    .content {
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
    }

    .tile {
      align-items: center;
      background-color: #fff;
      border-radius: 12px;
      box-shadow: transparent 0 0 0 3px, rgba(18, 18, 18, .1) 0 6px 20px;
      box-sizing: border-box;
      color: #121212;
      cursor: pointer;
      display: inline-flex;
      flex: 1 1 auto;
      font-family: Inter, sans-serif;
      font-size: 1.2rem;
      font-weight: 700;
      justify-content: center;
      line-height: 1;
      outline: none;
      margin: 20px;
      width: 10rem;
      height: 10rem;
      text-align: center;
      text-decoration: none;
      transition: box-shadow .2s, -webkit-box-shadow .2s;
      white-space: nowrap;
      border: 0;
      user-select: none;
      -webkit-user-select: none;
      touch-action: manipulation;
    }

    .tile:hover {
      box-shadow: #121212 0 0 0 3px, transparent 0 0 0 0;
    }
  </style>
</head>
<body>
  <div class="content">
    <h1>${REPO} Report Types</h1>
    <p>
EOF

  for report_dir in `ls -d ./docs/*/`; do
    report_name=$(basename "$report_dir")
    echo "<a href=\"./$report_name/index.html\" class=\"tile\">$report_name</a>" >> "$main_index_file"
  done

  echo "</p></div></body></html>" >> "$main_index_file"
  git add "$main_index_file"
  git config --global --add safe.directory /github/workspace
  git config user.name "${GITHUB_ACTOR}"
  git config user.email "${GITHUB_ACTOR_ID}+${GITHUB_ACTOR}@users.noreply.github.com"
  git commit --allow-empty -m "Add main index.html"
  git push origin $gh_pages_branch

  echo "::endgroup::"
fi
