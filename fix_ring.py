import os

filepath = "lib/home_screen.dart"
if os.path.exists(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Check if the blue border is still there
    old_ring = """border: Border.all(color: const Color(0xFF1D6FDC), width: 3),"""
    new_ring = """gradient: kStoryRing,"""
    
    if old_ring in content:
        content = content.replace(old_ring, new_ring)
        with open(filepath, 'w') as f:
            f.write(content)
        print("✅ Forced gradient ring on Profile!")
    else:
        print("ℹ️ Ring already updated or not found.")
