import os
import json
import urllib.request
import urllib.error

# --- CONFIGURATION ---
PROJECT_REF = "zxhyubnhbskikzgktwmp"
OUTPUT_FILE = "/storage/emulated/0/Download/Swifly_supabase_FULL_report.txt"

token = os.environ.get("SUPABASE_ACCESS_TOKEN")
if not token:
    print("Please enter your Supabase Access Token (sbp_...):")
    token = input().strip()

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

def run_query(sql):
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    data = json.dumps({"query": sql}).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return {"error": str(e)}

def get_api(endpoint):
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/{endpoint}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return {"error": str(e)}

def write_section(f, title, data):
    f.write("\n" + "="*60 + "\n")
    f.write(f" {title}\n")
    f.write("="*60 + "\n")
    f.write(json.dumps(data, indent=2) + "\n")

print("Fetching data from Supabase...")

with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    # 1-5. Database stuff (Tables, Indexes, RPC, RLS, Realtime)
    print(" -> Database Schema & Policies")
    write_section(f, "1. TABLES & COLUMNS", run_query("SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema = 'public' ORDER BY table_name, ordinal_position;"))
    write_section(f, "2. INDEXES", run_query("SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'public';"))
    write_section(f, "3. RPC FUNCTIONS", run_query("SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_schema = 'public';"))
    write_section(f, "4. RLS POLICIES", run_query("SELECT tablename, policyname, cmd, roles, qual FROM pg_policies WHERE schemaname = 'public';"))
    write_section(f, "5. REALTIME TABLES", run_query("SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';"))

    # 6. Edge Functions
    print(" -> Edge Functions (Metadata & Source Code)")
    funcs = get_api("functions")
    write_section(f, "6. EDGE FUNCTIONS METADATA", funcs)

    f.write("\n" + "="*60 + "\n")
    f.write(" 7. EDGE FUNCTIONS FULL SOURCE CODE\n")
    f.write("="*60 + "\n")
    
    if isinstance(funcs, list):
        for func in funcs:
            slug = func.get("slug")
            f.write(f"\n/* ======================================== */\n")
            f.write(f"/* FUNCTION: {slug} */\n")
            f.write(f"/* ======================================== */\n\n")
            
            # Look for the file locally in your Swifly folder
            local_path = f"supabase/functions/{slug}/index.ts"
            if os.path.exists(local_path):
                with open(local_path, 'r', encoding='utf-8') as src:
                    f.write(src.read() + "\n")
            else:
                f.write(f"// (Source code not found locally at {local_path})\n")
    else:
        f.write("Error fetching functions list.\n")

    # 8. Secrets
    print(" -> Secrets")
    write_section(f, "8. SECRETS (Names & Digests)", get_api("secrets"))

    # 9. Storage Buckets
    print(" -> Storage Buckets")
    write_section(f, "9. STORAGE BUCKETS", get_api("storage/buckets"))

print(f"\n✅ Done! The complete report with source code has been saved to:\n{OUTPUT_FILE}")
