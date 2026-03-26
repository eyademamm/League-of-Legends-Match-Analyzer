import pandas as pd

print("Loading Excel file...")
df = pd.read_excel('league_data.xlsx')

print("Converting to CSV...")
df.to_csv('league_data.csv', index=False)

print("Conversion complete!")