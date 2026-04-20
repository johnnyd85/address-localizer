# Address Localizer

A Salesforce DX project that bulk-geolocates **311 Case records** to any US city — without calling an external API. A user picks a city, previews how many cases will be affected, then clicks **Relocate Cases**. Each case is assigned a unique, geographically realistic latitude and longitude within a 5-mile radius of the city center.

This is primarily a **demo and development tool** — useful for populating realistic location data in sandbox or scratch orgs before testing maps, geospatial reports, or field service workflows.

---

## How It Works

1. The org stores a reference dataset of the **200 largest US cities** in a custom object (`CityCentroid__c`), each record holding the city name, state abbreviation, population, and the geographic centroid coordinates (latitude/longitude).
2. When a user submits the **Address Localizer** component, the Apex controller (`AddressLocalizerController`) looks up the matching `CityCentroid__c` record, then bulk-updates every 311 Case with a randomly generated coordinate inside a 5-mile radius of that centroid.
3. Random points are sampled uniformly across the disk (using the square-root trick) so coordinates are spread naturally across the city rather than clustered at the center.
4. Updates are performed with partial-success mode (`Database.update(cases, false)`), so a single bad record does not abort the entire batch.

---

## Project Contents

| Path | Description |
|---|---|
| `force-app/main/default/classes/AddressLocalizerController.cls` | Apex controller — resolves centroid, randomizes coordinates, bulk-updates Cases |
| `force-app/main/default/lwc/addressLocalizer/` | Lightning Web Component — city/state inputs, Preview, and Relocate Cases buttons |
| `force-app/main/default/objects/CityCentroid__c/` | Custom object definition and field metadata |
| `force-app/main/default/permissionsets/Address_Localizer_Access.permissionset-meta.xml` | Permission set granting access to `CityCentroid__c` |
| `us_cities_200.csv` | Reference data — 200 largest US cities with centroid coordinates and population |
| `addresslocalizertest.csv` | Sample 311 Case data for import into a scratch org or sandbox |

---

## Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) installed and up to date
- A Salesforce **scratch org** or **sandbox** with:
  - A **311 Case Record Type** (API name: `311`)
  - A geolocation compound field on the Case object (defaults to `Location__Latitude__s` / `Location__Longitude__s` — see [Configuration](#configuration) below)
  - A text field `City__c` and text field `State__c` on Case

---

## Deployment

### 1. Authenticate to your org

```bash
sf org login web --alias my-org
```

### 2. Deploy the metadata

```bash
sf project deploy start --target-org my-org
```

This deploys:
- The `CityCentroid__c` custom object and its fields
- The `AddressLocalizerController` Apex class
- The `addressLocalizer` Lightning Web Component
- The `Address_Localizer_Access` permission set

### 3. Assign the permission set

```bash
sf org assign permset --name Address_Localizer_Access --target-org my-org
```

### 4. Load the city centroid reference data

Import `us_cities_200.csv` using the Salesforce CLI data loader or Data Import Wizard:

```bash
sf data import bulk --sobject CityCentroid__c --file us_cities_200.csv --target-org my-org
```

### 5. (Optional) Load sample 311 Case data

`addresslocalizertest.csv` contains 51 sample 311 Cases for Portsmouth, NH that can be imported to test the component end-to-end.

```bash
sf data import bulk --sobject Case --file addresslocalizertest.csv --target-org my-org
```

---

## Adding the Component to a Page

1. Open **Lightning App Builder** (Setup → Lightning App Builder).
2. Edit an existing app page or create a new one.
3. Drag **Address Localizer** from the custom components panel onto the page canvas.
4. Save and activate the page.

---

## Using the Component

1. Enter a **City** name (e.g., `Nashville`) and a two-letter **State** abbreviation (e.g., `TN`).
2. Click **Preview** to see how many 311 Cases will be updated.
3. Click **Relocate Cases** to assign randomized coordinates to all 311 Cases within a 5-mile radius of the selected city.
4. A success or error banner (and a toast notification) confirms the result.

---

## Configuration

The Apex controller uses named constants at the top of the class that you can update to match your org's field API names without touching any other logic:

```apex
private static final String FIELD_LATITUDE   = 'Location__Latitude__s';
private static final String FIELD_LONGITUDE  = 'Location__Longitude__s';
private static final String FIELD_CITY       = 'City__c';
private static final String FIELD_STATE      = 'State__c';

private static final String RECORD_TYPE_NAME = '311';
private static final Double MAX_RADIUS_MILES = 5.0;
```

Update `FIELD_LATITUDE` and `FIELD_LONGITUDE` if your org uses a different geolocation compound field name. Change `MAX_RADIUS_MILES` to widen or narrow the geographic spread.

---

## License

This project is provided as-is for demonstration purposes. No warranty is expressed or implied.
