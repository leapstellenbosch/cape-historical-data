"""Load the Cape Historical Data Repository in Python.

Run from the repository folder. Needs pandas; pyarrow for the Parquet files.
"""
import glob
import os
import xml.etree.ElementTree as ET

import pandas as pd

# ---- Opgaaf tax censuses ----
units = pd.read_parquet("data/opgaaf/opgaaf_tax_units.parquet")
# or from CSV (low_memory=False: many variables appear only in later forms)
# units = pd.read_csv("data/opgaaf/opgaaf_tax_units.csv", low_memory=False)
sheets = pd.read_csv("data/opgaaf/opgaaf_sheet_inventory.csv")

# Form type is a property of the sheet (one per district and year)
units = units.merge(sheets[["district", "year", "form_type"]], on=["district", "year"], how="left")

# Enslaved adults declared in Stellenbosch, by year. min_count=1 keeps a year
# NA when nothing was recorded (blank is missing, not zero)
stb = units[(units.district == "Stellenbosch") & (units.form_type == "opgaaf_declaration_return")]
print(stb.groupby("year")[["slave_men", "slave_women"]].sum(min_count=1).tail())

entries = pd.read_parquet("data/opgaaf/opgaaf_entries.parquet")

# ---- Slave emancipation ----
# From CSV: only blank cells are missing; claim numbers are text ("508a")
ema = pd.read_csv("data/emancipation/emancipation_persons.csv", keep_default_na=False, na_values=[""],
                  dtype={"lbs_claim_number": str}, low_memory=False)
# Compensation is an award per claim, never summed over people. The distinct
# amounts of each claim; 26 claims have more than one (several owners, or
# slightly different entries): inspect them before adding up
claims = (ema.dropna(subset=["claim_compensation", "lbs_claim_number"])
          .drop_duplicates(["lbs_claim_number", "claim_compensation"])[["lbs_claim_number", "claim_compensation"]])
claims["n_amounts"] = claims.groupby("lbs_claim_number")["claim_compensation"].transform("size")
print((claims.n_amounts > 1).groupby(claims.lbs_claim_number).any().sum(), "claims with more than one amount")

# ---- SAF genealogies ----
persons = pd.read_parquet("data/saf/saf_persons.parquet")
marriages = pd.read_parquet("data/saf/saf_marriages.parquet")
# Each person's parents' marriage. A few codes are shared by two people
# (see id_flag), so a code can match more than one marriage.
with_parents = persons.merge(
    marriages[["spouse_code", "marriage_year"]].rename(columns={"marriage_year": "parents_marriage_year"}),
    left_on="mother_spouse_code", right_on="spouse_code", how="left")


# ---- Probate inventories and auction rolls (XML) ----
def read_documents(path):
    """One row per document: reference, date and deceased."""
    rows = []
    for div in ET.parse(path).getroot().findall("./body/div"):
        date = div.find("./head/date")
        name = div.find("./head/name")
        rows.append({"file": os.path.basename(path), "reference": div.get("n"),
                     "date": date.get("value") if date is not None else None,
                     "deceased": name.get("reg") if name is not None else None})
    return rows


probate = pd.DataFrame([r for f in sorted(glob.glob("data/probate/xml/*.xml")) for r in read_documents(f)])
print(len(probate), "probate documents")

# The lots of one auction: item, buyer and price are the cells of each row
roll = ET.parse("data/auctions/xml/MOOC10_vol25.xml").getroot()
sale = next(d for d in roll.findall("./body/div") if d.get("n") == "MOOC10/25.2")
lots = [["".join(c.itertext()).strip() for c in row.findall("./cell")] for row in sale.iter("row")]
print(lots[:5])
