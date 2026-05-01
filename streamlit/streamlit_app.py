"""Expense Rodeo -- Streamlit in Snowflake dashboard.

Lets finance users browse extracted receipts, compare the raw file against the
typed fields, and see aggregate spend by category and vendor.
"""

from datetime import timedelta

import pandas as pd
import streamlit as st
from snowflake.snowpark.context import get_active_session


st.set_page_config(
    page_title="Receipt Explorer",
    page_icon=":page_facing_up:",
    layout="wide",
)

session = get_active_session()

SCHEMA = "SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR"
STAGE = f"@{SCHEMA}.RECEIPTS_STAGE"


@st.cache_data(ttl=60)
def load_receipts() -> pd.DataFrame:
    return session.sql(
        f"SELECT * FROM {SCHEMA}.RECEIPTS ORDER BY RECEIPT_DATE DESC, FILE_PATH"
    ).to_pandas()


@st.cache_data(ttl=60)
def load_spend_by_category() -> pd.DataFrame:
    return session.sql(
        f"SELECT * FROM {SCHEMA}.V_SPEND_BY_CATEGORY ORDER BY TOTAL_SPEND DESC"
    ).to_pandas()


@st.cache_data(ttl=60)
def load_spend_by_vendor() -> pd.DataFrame:
    return session.sql(
        f"SELECT * FROM {SCHEMA}.V_SPEND_BY_VENDOR ORDER BY TOTAL_SPEND DESC LIMIT 20"
    ).to_pandas()


def presigned_url(file_path: str) -> str | None:
    try:
        row = session.sql(
            f"SELECT GET_PRESIGNED_URL({STAGE!s}, ?, 3600) AS URL",
            params=[file_path],
        ).collect()
        return row[0]["URL"] if row else None
    except Exception:
        return None


receipts = load_receipts()

# ---- Header ----------------------------------------------------------------
st.title("Receipt Explorer")
st.caption(
    "AI_EXTRACT turns unstructured expense receipts into the typed `RECEIPTS` "
    "fact table. Pick a row to audit the extraction."
)

# ---- KPI row ---------------------------------------------------------------
if receipts.empty:
    st.warning("No receipts yet. Drop files in @RECEIPTS_STAGE and call SP_RECEIPT_EXTRACT_ALL().")
    st.stop()

kpi1, kpi2, kpi3, kpi4 = st.columns(4)
kpi1.metric("Receipts", f"{len(receipts):,}")
kpi2.metric("Total spend", f"${receipts['TOTAL_AMOUNT'].sum():,.2f}")
kpi3.metric("Avg receipt", f"${receipts['TOTAL_AMOUNT'].mean():,.2f}")
kpi4.metric("Vendors", f"{receipts['VENDOR'].nunique():,}")

st.divider()

# ---- Filters ---------------------------------------------------------------
with st.sidebar:
    st.header("Filters")
    categories = st.multiselect(
        "Category",
        options=sorted(receipts["CATEGORY"].dropna().unique()),
        default=None,
    )
    min_date = receipts["RECEIPT_DATE"].min()
    max_date = receipts["RECEIPT_DATE"].max()
    date_range = st.date_input(
        "Receipt date",
        value=(min_date, max_date),
        min_value=min_date,
        max_value=max_date,
    )

filtered = receipts.copy()
if categories:
    filtered = filtered[filtered["CATEGORY"].isin(categories)]
if isinstance(date_range, tuple) and len(date_range) == 2:
    start, end = date_range
    filtered = filtered[
        (filtered["RECEIPT_DATE"] >= start) & (filtered["RECEIPT_DATE"] <= end)
    ]

# ---- Layout: picker + detail ----------------------------------------------
left, right = st.columns([2, 3])

with left:
    st.subheader("Receipts")
    st.dataframe(
        filtered[["FILE_PATH", "VENDOR", "RECEIPT_DATE", "CATEGORY", "TOTAL_AMOUNT"]],
        hide_index=True,
        use_container_width=True,
        column_config={
            "TOTAL_AMOUNT": st.column_config.NumberColumn("Total", format="$%.2f"),
            "RECEIPT_DATE": st.column_config.DateColumn("Date"),
        },
    )
    choice = st.selectbox(
        "Select a receipt to inspect",
        options=filtered["FILE_PATH"].tolist() if not filtered.empty else [],
    )

with right:
    if choice:
        row = filtered[filtered["FILE_PATH"] == choice].iloc[0]
        st.subheader(row["VENDOR"] or "(unknown vendor)")
        st.caption(f"File: `{row['FILE_PATH']}`")

        meta_a, meta_b, meta_c = st.columns(3)
        meta_a.metric("Date",   str(row["RECEIPT_DATE"]))
        meta_b.metric("Total",  f"${row['TOTAL_AMOUNT']:,.2f} {row['CURRENCY']}")
        meta_c.metric("Category", row["CATEGORY"] or "-")

        st.markdown("**Payment method:** " + (row["PAYMENT_METHOD"] or "-"))

        url = presigned_url(row["FILE_PATH"])
        if url:
            lower = row["FILE_PATH"].lower()
            if lower.endswith((".jpg", ".jpeg", ".png", ".tif", ".tiff")):
                st.image(url, caption=row["FILE_PATH"], use_container_width=True)
            else:
                st.markdown(f"[Open source file]({url})")

        st.markdown("**Line items**")
        line_items = row["LINE_ITEMS"]
        if line_items is not None:
            if isinstance(line_items, str):
                import json
                line_items = json.loads(line_items)
            st.dataframe(pd.DataFrame(line_items), hide_index=True, use_container_width=True)
        else:
            st.write("No line items extracted.")

st.divider()

# ---- Aggregates ------------------------------------------------------------
agg_left, agg_right = st.columns(2)

with agg_left:
    st.subheader("Spend by category")
    by_cat = load_spend_by_category()
    st.bar_chart(by_cat.set_index("CATEGORY")["TOTAL_SPEND"])

with agg_right:
    st.subheader("Top vendors")
    by_vendor = load_spend_by_vendor()
    st.bar_chart(by_vendor.set_index("VENDOR")["TOTAL_SPEND"])

st.caption(
    "Data source: `SNOWFLAKE_EXAMPLE.RECEIPT_EXTRACTOR.RECEIPTS` (populated via "
    "`SP_RECEIPT_EXTRACT_ALL`). Semantic view for Cortex Analyst: "
    "`SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS.SV_RECEIPT_EXTRACTOR`."
)
