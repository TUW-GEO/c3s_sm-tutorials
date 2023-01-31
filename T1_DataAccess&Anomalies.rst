**C3S Soil Moisture Data Access and Anomaly Analysis Notebook**
===============================================================

|Binder|

*Note: Cells in this notebook are meant to be executed* **in order**
*(from top to bottom). Some of the later examples depend on previous
ones!*

.. |Binder| image:: https://mybinder.org/badge_logo.svg
   :target: https://mybinder.org/v2/gh/TUW-GEO/c3s_sm-tutorials/v1.0

First we import all libraries necessary to run code in this notebook.
Some of them are python standard libraries, that are installed by
default. Other libraries can be installed using the ``conda`` package
manager via:

::

   !conda install -y -c conda-forge <PACKAGE>

A full list of dependencies required to run this notebook is available
in the file ``environment.yml`` at
https://github.com/TUW-GEO/c3s_sm-tutorials. If you are on Binder (click
bade at the top), all necessary dependencies are already installed.

We also make sure to install the `CDS
API <https://pypi.org/project/cdsapi/>`__ via ``pip`` by running:

.. code:: ipython3

    %%capture --no-display
    !pip install cdsapi

.. code:: ipython3

    import os
    import cdsapi
    from pathlib import Path
    from tempfile import TemporaryDirectory
    import ipywidgets as widgets
    import matplotlib.pyplot as plt
    import cartopy
    import cartopy.crs as ccrs
    import xarray as xr
    from scipy.stats import theilslopes
    import numpy as np
    import shutil
    import pandas as pd
    import zipfile
    from collections import OrderedDict
    %matplotlib inline

The file ``utils.py`` is part of this package. It contains helper
functions that are not relevant to understand contents of the notebook
and therefore transferred to a separate file.

.. code:: ipython3

    import utils as utils

About C3S Satellite Soil Moisture
=================================

Satellites sensors can observe the amount of water stored in the top
layer of the soil from space. Various satellite missions from different
space agencies provide measurements of radiation from the Earth’s
surface across different (microwave) frequency domains (Ku-, X,- C- and
L-band), which are related to the amount of water stored in the soil.
There are two types of sensors that are used to measure this
information: passive systems (radiometer) and active systems (radar).

.. raw:: html

   <center>

.. raw:: html

   </center>

For a detailed description, please see the C3S Soil Moisture Algorithm
Theoretical Baseline Document, which is available together with the data
at the `Copernicus Climate Data
Store <https://cds.climate.copernicus.eu/cdsapp#!/dataset/10.24381/cds.d7782f18>`__.

Soil moisture from radiometer measurements (PASSIVE)
----------------------------------------------------

Brightness temperature is the observable of passive sensors (in
:math:`°K`). It is a function of kinetic temperature and emissivity. Wet
soils have a higher emissivity than dry soils and therefore a higher
brightness temperature. Passive soil moisture retrieval uses this
difference between kinetic temperature and brightness temperature to
model the amount of water available in the soil of the observed area,
while taking into account factors such as the water held by vegetation.

NASA’s SMAP and ESA’s SMOS satellites are examples for L-band radiometer
missions. They are suitable for retrieving soil moisture globally, even
when vegetation is present in a scene.

Different models to retrieve Soil Moisture from brightness temperature
measurements exist. One of the them is the Land Parameter Retrieval
Model (`Owe et al., 2008 <https://doi.org/10.1029/98WR01469>`__, `Owe et
al., 2001 <https://doi.org/10.1109/36.942542>`__, and `van der Schalie
et al., 2016 <https://doi.org/10.1016/j.jag.2015.08.005>`__). This model
is used to derive soil moisture for all passive sensors in C3S.

The PASSIVE product of C3S Soil Moisture contains merged observations
from passive systems only. It is given in volumetric units
:math:`[m^3 / m^3]`.

Soil moisture from scatterometer measurements (ACTIVE)
------------------------------------------------------

Active systems emit radiation in the microwave domain (C-band in C3S).
As the energy pulses emitted by the radar hit the Earth’s surface, a
scattering effect occurs and part of the energy is reflected back,
containing information on the surface state of the observed scene. The
received energy is called “backscatter”, with rough and wet surfaces
producing stronger signals than smooth or dry surfaces. Backscatter
comprises reflections from the soil surface layer (“surface scatter”),
vegetation (“volume scatter”) and interactions of the two.

ESA’s ERS-1 and ERS-2, as well as EUMETSAT’s Metop ASCAT sensors are
active systems used in C3S soil moisture. In the case of Metop ASCAT,
C3S Soil Moisture uses the Surface Soil Moisture products directly
provided by `H SAF <https://hsaf.meteoam.it/>`__, based on the WARP
algorithm (`Wagner et al.,
1999 <https://doi.org/10.1016/S0034-4257(99)00036-X>`__, `Wagner et al.,
2013 <https://publik.tuwien.ac.at/files/PubDat_217985.pdf>`__).

The ACTIVE product of C3S Soil Moisture contains merged observations
from active systems only. It is given in relative units :math:`[\%`
:math:`saturation]`.

Merged product (COMBINED)
-------------------------

Single-sensor products are limited by the life time of the satellite
sensors. Climate change assessments, however, require the use of
long-term data records, that span over multiple decades and provide
consistent and comparable observations. The C3S Soil Moisture record
therefore merges the observations from more than 15 sensors into one
harmonized record. The main 2 steps of the product generation include
scaling all sensors to a common reference, and subsequently merging them
by applying a weighted average, where sensor with a lower error are
assigned a higher weight. The following figure shows all satellite
sensors merged in the PASSIVE (only radiometers), ACTIVE (only
scatterometers) and COMBINED (scatterometers and radiometers) product
(data set version v202212).

.. raw:: html

   <center>

.. raw:: html

   </center>

C3S Soil Moisture is based on the ESA CCI SM algorithm, which is
described in `Dorigo et al.,
2017 <https://doi.org/10.1016/j.rse.2017.07.001.>`__ and `Gruber et al.,
2019 <https://doi.org/10.5194/essd-11-717-2019>`__.

The COMBINED product is also given in volumetric units
:math:`[m^3 / m^3]`. However, the absolute values depend on the scaling
reference, which is used to bring all sensors into the same dynamic
range. In this case we use Soil Moisture simulations for the first 10 cm
from the GLDAS Noah model (`Rodell et al.,
2004 <https://doi.org/10.1175/BAMS-85-3-381>`__).

Data Access and Download
========================

Different products and versions for C3S Soil Moisture are available on
the `Copernicus Climate Data
Store <https://cds.climate.copernicus.eu/#!/home>`__. In general, there
are 2 types of data records: - **CDR**: The long term Climate Data
Record, processed every 1-2 years, contains data for more than 40 years,
but not up-to-date. - **ICDR**: Interim Climate Data Record, updated
every 10-20 days, extends the CDR, contains up-to-date (harmonised)
observations to append to the CDR.

Creating a valid CDS data request for satellite soil moisture
-------------------------------------------------------------

There are different options to specify a valid C3S Soil Moisture data
request. You can use the `CDS
GUI <https://cds.climate.copernicus.eu/cdsapp#!/dataset/satellite-soil-moisture?tab=form>`__
to generate a valid request (button ``Show API Request``) and copy/paste
it to your python script as shown below. To summarize the options:

-  **``variable``**: Either ``volumetric_surface_soil_moisture`` (must
   be chosen to download the PASSIVE or COMBINED data) or
   ``surface_soil_moisture`` (required for ACTIVE product)
-  **``type_of_sensor``**: One of ``active``, ``passive`` or
   ``combined_passive_and_active`` (must match with the selected
   variable!)
-  **``time_aggregation``**: ``month_average``, ``10_day_average``, or
   ``day_average``. The original data is daily. Monthly and 10-daily
   averages are often required for climate analyses and therefore
   provided for convenience.
-  **``year``**: a list of years to download data for (COMBINED and
   PASSIVE data is available from **1978** onward, ACTIVE starts in
   **1991**)
-  **``month``**: a list of months to download data.
-  **``day``**: a list of days to download data for (note that for the
   monthly data, ``day`` must always be ‘01’. For the 10-daily average,
   valid ``days`` are: ‘01’, ‘11’, ‘21’ (therefore the day always refers
   to the start of the period the data represents).
-  *``area``*: (optional) Coordinates of a bounding box to download data
   for.
-  **``type_of_record``**: ``cdr`` and/or ``icdr``. It is recommended to
   select both, to use whichever data is available (there is no overlap
   between ICDR and CDR of a major version).
-  **``version``**: Data record version, currently available:
   ``v201706.0.0``, ``v201812.0.0``, ``v201812.0.1``, ``v201912.0.0``,
   ``v202012.0.0``, ``v202012.0.1``, ``v202012.0.2`` (new versions are
   added regularly). Sub-versions indicate new data that is meant to
   replace the previous sub-versions (e.g. due to processing errors). It
   is therefore recommended to pass all sub-versions and use the file
   with the highest version for any time stamp in case of duplicate time
   stamps.
-  **``format``**: Either ``zip`` or ``tgz``. Archive format that holds
   the individual netcdf images.

Getting your CDS API Key
------------------------

In order to download data from the Climate Data Store (CDS) via the API
you need: 1) An account at https://cds.climate.copernicus.eu 2) Your
personal API key from https://cds.climate.copernicus.eu/api-how-to

If you do not provide a valid KEY in the next cell, the following API
request will fail. However, you can then still continue with the example
data provided together with this notebook, which is the same data you
would get if the query is not changed: i.e., monthly volumetric surface
soil moisture from passive observations at version *v202012* over
Europe, from CDR & ICDR. The provided example data is stored in the
repository as this notebook (``./DATA/sm_monthly_passive_v202012.zip``).
It is recommended to use **monthly** data, as some of the examples in
this notebook will not work with daily or 10-daily images!

.. code:: ipython3

    URL = 'https://cds.climate.copernicus.eu/api/v2'
    # If you have a valid key, set it in the following line:
    KEY = "######################################"

.. code:: ipython3

    try:
        c = cdsapi.Client(url=URL, key=KEY)
        DATA_PATH = Path('DATA') / 'my_data.zip'
        c.retrieve(
            'satellite-soil-moisture',
            {   'variable': 'volumetric_surface_soil_moisture',
                'type_of_sensor': 'passive',
                'time_aggregation': 'month_average', # required for examples in this notebook
                'year': [str(y) for y in range(1991, 2023)],
                'month': [f"{m:02}" for m in range(1, 13)],
                'day': '01',
                'area': [72, -11, 34, 40],
                'type_of_record': ['cdr', 'icdr'],
                'version': ['v202012.0.0', 'v202012.0.1', 'v202012.0.2'],
                'format': 'zip',
            },
            DATA_PATH
        )
    except Exception as e:
        DATA_PATH = Path('DATA') / 'sm_monthly_passive_v202012.zip'
        print("Could not download data from CDS using the passed request and/or API Key.\n"
              f"The following error was raised: \n   {e} \n \n"
              f"We therefore continue with the data provided in: {DATA_PATH}")


.. parsed-literal::

    2023-01-31 16:50:10,891 INFO Sending request to https://cds.climate.copernicus.eu/api/v2/resources/satellite-soil-moisture


.. parsed-literal::

    Could not download data from CDS using the passed request and/or API Key.
    The following error was raised: 
       'tuple' object is not callable 
     
    We therefore continue with the data provided in: DATA/sm_monthly_passive_v202012.zip


Unpacking and loading data with xarray
--------------------------------------

From the previous cell, we have a variable ``DATA_PATH`` which points to
a .zip archive (either newly downloaded or provided) containing the
selected data from CDS as individual images. We use the library
`xarray <xarray.pydata.org/>`__ to read these data, but first we have to
extract them. In the next cell we extract all files from the downloaded
.zip archive into a new folder. We do this using standard python
libraries:

.. code:: ipython3

    # Setting up a temporary folder to extract data to:
    extracted_data = Path(f"{DATA_PATH}_extracted")
    if os.path.exists(extracted_data):
        shutil.rmtree(extracted_data)
    os.makedirs(extracted_data)
    
    # Extract all files from zip:
    with zipfile.ZipFile(DATA_PATH, 'r') as archive:
        archive.extractall(extracted_data)

We can then use the function
`xarray.open_mfdataset <https://docs.xarray.dev/en/stable/generated/xarray.open_mfdataset.html>`__
to load all extracted files and concatenate them along the time
dimension automatically. This way we get a 3-dimensional (longitude,
latitude, time) data cube, that we store in a global variable ``DS``. In
addition we extract the unit and valid range of the soil moisture
variable from the netCDF metadata (``SM_UNIT`` and ``SM_RANGE``).
Finally we plot a table that shows the contents of ``DS``.

.. code:: ipython3

    DS = xr.open_mfdataset(os.path.join(extracted_data, "*.nc"))
    SM_UNIT = DS['sm'].attrs['units']
    SM_RANGE = DS['sm'].attrs['valid_range']
    
    display(DS)



.. raw:: html

    <div><svg style="position: absolute; width: 0; height: 0; overflow: hidden">
    <defs>
    <symbol id="icon-database" viewBox="0 0 32 32">
    <path d="M16 0c-8.837 0-16 2.239-16 5v4c0 2.761 7.163 5 16 5s16-2.239 16-5v-4c0-2.761-7.163-5-16-5z"></path>
    <path d="M16 17c-8.837 0-16-2.239-16-5v6c0 2.761 7.163 5 16 5s16-2.239 16-5v-6c0 2.761-7.163 5-16 5z"></path>
    <path d="M16 26c-8.837 0-16-2.239-16-5v6c0 2.761 7.163 5 16 5s16-2.239 16-5v-6c0 2.761-7.163 5-16 5z"></path>
    </symbol>
    <symbol id="icon-file-text2" viewBox="0 0 32 32">
    <path d="M28.681 7.159c-0.694-0.947-1.662-2.053-2.724-3.116s-2.169-2.030-3.116-2.724c-1.612-1.182-2.393-1.319-2.841-1.319h-15.5c-1.378 0-2.5 1.121-2.5 2.5v27c0 1.378 1.122 2.5 2.5 2.5h23c1.378 0 2.5-1.122 2.5-2.5v-19.5c0-0.448-0.137-1.23-1.319-2.841zM24.543 5.457c0.959 0.959 1.712 1.825 2.268 2.543h-4.811v-4.811c0.718 0.556 1.584 1.309 2.543 2.268zM28 29.5c0 0.271-0.229 0.5-0.5 0.5h-23c-0.271 0-0.5-0.229-0.5-0.5v-27c0-0.271 0.229-0.5 0.5-0.5 0 0 15.499-0 15.5 0v7c0 0.552 0.448 1 1 1h7v19.5z"></path>
    <path d="M23 26h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
    <path d="M23 22h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
    <path d="M23 18h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
    </symbol>
    </defs>
    </svg>
    <style>/* CSS stylesheet for displaying xarray objects in jupyterlab.
     *
     */
    
    :root {
      --xr-font-color0: var(--jp-content-font-color0, rgba(0, 0, 0, 1));
      --xr-font-color2: var(--jp-content-font-color2, rgba(0, 0, 0, 0.54));
      --xr-font-color3: var(--jp-content-font-color3, rgba(0, 0, 0, 0.38));
      --xr-border-color: var(--jp-border-color2, #e0e0e0);
      --xr-disabled-color: var(--jp-layout-color3, #bdbdbd);
      --xr-background-color: var(--jp-layout-color0, white);
      --xr-background-color-row-even: var(--jp-layout-color1, white);
      --xr-background-color-row-odd: var(--jp-layout-color2, #eeeeee);
    }
    
    html[theme=dark],
    body[data-theme=dark],
    body.vscode-dark {
      --xr-font-color0: rgba(255, 255, 255, 1);
      --xr-font-color2: rgba(255, 255, 255, 0.54);
      --xr-font-color3: rgba(255, 255, 255, 0.38);
      --xr-border-color: #1F1F1F;
      --xr-disabled-color: #515151;
      --xr-background-color: #111111;
      --xr-background-color-row-even: #111111;
      --xr-background-color-row-odd: #313131;
    }
    
    .xr-wrap {
      display: block !important;
      min-width: 300px;
      max-width: 700px;
    }
    
    .xr-text-repr-fallback {
      /* fallback to plain text repr when CSS is not injected (untrusted notebook) */
      display: none;
    }
    
    .xr-header {
      padding-top: 6px;
      padding-bottom: 6px;
      margin-bottom: 4px;
      border-bottom: solid 1px var(--xr-border-color);
    }
    
    .xr-header > div,
    .xr-header > ul {
      display: inline;
      margin-top: 0;
      margin-bottom: 0;
    }
    
    .xr-obj-type,
    .xr-array-name {
      margin-left: 2px;
      margin-right: 10px;
    }
    
    .xr-obj-type {
      color: var(--xr-font-color2);
    }
    
    .xr-sections {
      padding-left: 0 !important;
      display: grid;
      grid-template-columns: 150px auto auto 1fr 20px 20px;
    }
    
    .xr-section-item {
      display: contents;
    }
    
    .xr-section-item input {
      display: none;
    }
    
    .xr-section-item input + label {
      color: var(--xr-disabled-color);
    }
    
    .xr-section-item input:enabled + label {
      cursor: pointer;
      color: var(--xr-font-color2);
    }
    
    .xr-section-item input:enabled + label:hover {
      color: var(--xr-font-color0);
    }
    
    .xr-section-summary {
      grid-column: 1;
      color: var(--xr-font-color2);
      font-weight: 500;
    }
    
    .xr-section-summary > span {
      display: inline-block;
      padding-left: 0.5em;
    }
    
    .xr-section-summary-in:disabled + label {
      color: var(--xr-font-color2);
    }
    
    .xr-section-summary-in + label:before {
      display: inline-block;
      content: '►';
      font-size: 11px;
      width: 15px;
      text-align: center;
    }
    
    .xr-section-summary-in:disabled + label:before {
      color: var(--xr-disabled-color);
    }
    
    .xr-section-summary-in:checked + label:before {
      content: '▼';
    }
    
    .xr-section-summary-in:checked + label > span {
      display: none;
    }
    
    .xr-section-summary,
    .xr-section-inline-details {
      padding-top: 4px;
      padding-bottom: 4px;
    }
    
    .xr-section-inline-details {
      grid-column: 2 / -1;
    }
    
    .xr-section-details {
      display: none;
      grid-column: 1 / -1;
      margin-bottom: 5px;
    }
    
    .xr-section-summary-in:checked ~ .xr-section-details {
      display: contents;
    }
    
    .xr-array-wrap {
      grid-column: 1 / -1;
      display: grid;
      grid-template-columns: 20px auto;
    }
    
    .xr-array-wrap > label {
      grid-column: 1;
      vertical-align: top;
    }
    
    .xr-preview {
      color: var(--xr-font-color3);
    }
    
    .xr-array-preview,
    .xr-array-data {
      padding: 0 5px !important;
      grid-column: 2;
    }
    
    .xr-array-data,
    .xr-array-in:checked ~ .xr-array-preview {
      display: none;
    }
    
    .xr-array-in:checked ~ .xr-array-data,
    .xr-array-preview {
      display: inline-block;
    }
    
    .xr-dim-list {
      display: inline-block !important;
      list-style: none;
      padding: 0 !important;
      margin: 0;
    }
    
    .xr-dim-list li {
      display: inline-block;
      padding: 0;
      margin: 0;
    }
    
    .xr-dim-list:before {
      content: '(';
    }
    
    .xr-dim-list:after {
      content: ')';
    }
    
    .xr-dim-list li:not(:last-child):after {
      content: ',';
      padding-right: 5px;
    }
    
    .xr-has-index {
      font-weight: bold;
    }
    
    .xr-var-list,
    .xr-var-item {
      display: contents;
    }
    
    .xr-var-item > div,
    .xr-var-item label,
    .xr-var-item > .xr-var-name span {
      background-color: var(--xr-background-color-row-even);
      margin-bottom: 0;
    }
    
    .xr-var-item > .xr-var-name:hover span {
      padding-right: 5px;
    }
    
    .xr-var-list > li:nth-child(odd) > div,
    .xr-var-list > li:nth-child(odd) > label,
    .xr-var-list > li:nth-child(odd) > .xr-var-name span {
      background-color: var(--xr-background-color-row-odd);
    }
    
    .xr-var-name {
      grid-column: 1;
    }
    
    .xr-var-dims {
      grid-column: 2;
    }
    
    .xr-var-dtype {
      grid-column: 3;
      text-align: right;
      color: var(--xr-font-color2);
    }
    
    .xr-var-preview {
      grid-column: 4;
    }
    
    .xr-index-preview {
      grid-column: 2 / 5;
      color: var(--xr-font-color2);
    }
    
    .xr-var-name,
    .xr-var-dims,
    .xr-var-dtype,
    .xr-preview,
    .xr-attrs dt {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      padding-right: 10px;
    }
    
    .xr-var-name:hover,
    .xr-var-dims:hover,
    .xr-var-dtype:hover,
    .xr-attrs dt:hover {
      overflow: visible;
      width: auto;
      z-index: 1;
    }
    
    .xr-var-attrs,
    .xr-var-data,
    .xr-index-data {
      display: none;
      background-color: var(--xr-background-color) !important;
      padding-bottom: 5px !important;
    }
    
    .xr-var-attrs-in:checked ~ .xr-var-attrs,
    .xr-var-data-in:checked ~ .xr-var-data,
    .xr-index-data-in:checked ~ .xr-index-data {
      display: block;
    }
    
    .xr-var-data > table {
      float: right;
    }
    
    .xr-var-name span,
    .xr-var-data,
    .xr-index-name div,
    .xr-index-data,
    .xr-attrs {
      padding-left: 25px !important;
    }
    
    .xr-attrs,
    .xr-var-attrs,
    .xr-var-data,
    .xr-index-data {
      grid-column: 1 / -1;
    }
    
    dl.xr-attrs {
      padding: 0;
      margin: 0;
      display: grid;
      grid-template-columns: 125px auto;
    }
    
    .xr-attrs dt,
    .xr-attrs dd {
      padding: 0;
      margin: 0;
      float: left;
      padding-right: 10px;
      width: auto;
    }
    
    .xr-attrs dt {
      font-weight: normal;
      grid-column: 1;
    }
    
    .xr-attrs dt:hover span {
      display: inline-block;
      background: var(--xr-background-color);
      padding-right: 10px;
    }
    
    .xr-attrs dd {
      grid-column: 2;
      white-space: pre-wrap;
      word-break: break-all;
    }
    
    .xr-icon-database,
    .xr-icon-file-text2,
    .xr-no-icon {
      display: inline-block;
      vertical-align: middle;
      width: 1em;
      height: 1.5em !important;
      stroke-width: 0;
      stroke: currentColor;
      fill: currentColor;
    }
    </style><pre class='xr-text-repr-fallback'>&lt;xarray.Dataset&gt;
    Dimensions:     (lat: 152, lon: 204, time: 384)
    Coordinates:
      * lat         (lat) float32 71.88 71.62 71.38 71.12 ... 34.62 34.38 34.12
      * lon         (lon) float32 -10.88 -10.62 -10.38 -10.12 ... 39.38 39.62 39.88
      * time        (time) datetime64[ns] 1991-01-01 1991-02-01 ... 2022-12-01
    Data variables:
        sm          (time, lat, lon) float32 dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;
        sensor      (time, lat, lon) float32 dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;
        freqbandID  (time, lat, lon) float32 dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;
        nobs        (time, lat, lon) float32 dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;
    Attributes: (12/40)
        title:                      C3S Surface Soil Moisture merged PASSIVE Product
        institution:                EODC (AUT); TU Wien (AUT); VanderSat B.V. (NL)
        contact:                    C3S_SM_Science@eodc.eu
        source:                     LPRMv6/SMMR/Nimbus 7 L3 Surface Soil Moisture...
        platform:                   Nimbus 7, DMSP, TRMM, AQUA, Coriolis, GCOM-W1...
        sensor:                     SMMR, SSM/I, TMI, AMSR-E, WindSat, AMSR2, SMO...
        ...                         ...
        id:                         C3S-SOILMOISTURE-L3S-SSMV-PASSIVE-MONTHLY-199...
        history:                    2021-03-29T13:46:57.630282 mean calculated
        date_created:               2021-03-29T13:46:57Z
        time_coverage_start:        1990-12-31T12:00:00Z
        time_coverage_end:          1991-01-31T12:00:00Z
        time_coverage_duration:     P1M</pre><div class='xr-wrap' style='display:none'><div class='xr-header'><div class='xr-obj-type'>xarray.Dataset</div></div><ul class='xr-sections'><li class='xr-section-item'><input id='section-d1d7a80b-e6d3-42e1-b1f9-71724b00c939' class='xr-section-summary-in' type='checkbox' disabled ><label for='section-d1d7a80b-e6d3-42e1-b1f9-71724b00c939' class='xr-section-summary'  title='Expand/collapse section'>Dimensions:</label><div class='xr-section-inline-details'><ul class='xr-dim-list'><li><span class='xr-has-index'>lat</span>: 152</li><li><span class='xr-has-index'>lon</span>: 204</li><li><span class='xr-has-index'>time</span>: 384</li></ul></div><div class='xr-section-details'></div></li><li class='xr-section-item'><input id='section-f43eaa50-e4df-4f7e-9782-1c57db74f116' class='xr-section-summary-in' type='checkbox'  checked><label for='section-f43eaa50-e4df-4f7e-9782-1c57db74f116' class='xr-section-summary' >Coordinates: <span>(3)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>lat</span></div><div class='xr-var-dims'>(lat)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>71.88 71.62 71.38 ... 34.38 34.12</div><input id='attrs-ea53edbb-5e64-4248-b64b-921c15783b02' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-ea53edbb-5e64-4248-b64b-921c15783b02' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-db0eebb1-e538-4868-8837-bf118178f8b4' class='xr-var-data-in' type='checkbox'><label for='data-db0eebb1-e538-4868-8837-bf118178f8b4' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>standard_name :</span></dt><dd>latitude</dd><dt><span>units :</span></dt><dd>degrees_north</dd><dt><span>valid_range :</span></dt><dd>[-90.  90.]</dd><dt><span>_CoordinateAxisType :</span></dt><dd>Lat</dd></dl></div><div class='xr-var-data'><pre>array([71.875, 71.625, 71.375, 71.125, 70.875, 70.625, 70.375, 70.125, 69.875,
           69.625, 69.375, 69.125, 68.875, 68.625, 68.375, 68.125, 67.875, 67.625,
           67.375, 67.125, 66.875, 66.625, 66.375, 66.125, 65.875, 65.625, 65.375,
           65.125, 64.875, 64.625, 64.375, 64.125, 63.875, 63.625, 63.375, 63.125,
           62.875, 62.625, 62.375, 62.125, 61.875, 61.625, 61.375, 61.125, 60.875,
           60.625, 60.375, 60.125, 59.875, 59.625, 59.375, 59.125, 58.875, 58.625,
           58.375, 58.125, 57.875, 57.625, 57.375, 57.125, 56.875, 56.625, 56.375,
           56.125, 55.875, 55.625, 55.375, 55.125, 54.875, 54.625, 54.375, 54.125,
           53.875, 53.625, 53.375, 53.125, 52.875, 52.625, 52.375, 52.125, 51.875,
           51.625, 51.375, 51.125, 50.875, 50.625, 50.375, 50.125, 49.875, 49.625,
           49.375, 49.125, 48.875, 48.625, 48.375, 48.125, 47.875, 47.625, 47.375,
           47.125, 46.875, 46.625, 46.375, 46.125, 45.875, 45.625, 45.375, 45.125,
           44.875, 44.625, 44.375, 44.125, 43.875, 43.625, 43.375, 43.125, 42.875,
           42.625, 42.375, 42.125, 41.875, 41.625, 41.375, 41.125, 40.875, 40.625,
           40.375, 40.125, 39.875, 39.625, 39.375, 39.125, 38.875, 38.625, 38.375,
           38.125, 37.875, 37.625, 37.375, 37.125, 36.875, 36.625, 36.375, 36.125,
           35.875, 35.625, 35.375, 35.125, 34.875, 34.625, 34.375, 34.125],
          dtype=float32)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>lon</span></div><div class='xr-var-dims'>(lon)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>-10.88 -10.62 ... 39.62 39.88</div><input id='attrs-7ec7cc8e-bbf7-40c6-a080-d26ee5448610' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-7ec7cc8e-bbf7-40c6-a080-d26ee5448610' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-913fbad1-e749-4641-97bb-4b6fb496afe8' class='xr-var-data-in' type='checkbox'><label for='data-913fbad1-e749-4641-97bb-4b6fb496afe8' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>standard_name :</span></dt><dd>longitude</dd><dt><span>units :</span></dt><dd>degrees_east</dd><dt><span>valid_range :</span></dt><dd>[-180.  180.]</dd><dt><span>_CoordinateAxisType :</span></dt><dd>Lon</dd></dl></div><div class='xr-var-data'><pre>array([-10.875, -10.625, -10.375, ...,  39.375,  39.625,  39.875],
          dtype=float32)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>time</span></div><div class='xr-var-dims'>(time)</div><div class='xr-var-dtype'>datetime64[ns]</div><div class='xr-var-preview xr-preview'>1991-01-01 ... 2022-12-01</div><input id='attrs-31a14c5c-fbc0-41ee-aa6b-86e662669bc1' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-31a14c5c-fbc0-41ee-aa6b-86e662669bc1' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-7a621246-f438-47c8-a30b-b0382b726a8d' class='xr-var-data-in' type='checkbox'><label for='data-7a621246-f438-47c8-a30b-b0382b726a8d' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>standard_name :</span></dt><dd>time</dd><dt><span>_CoordinateAxisType :</span></dt><dd>Time</dd></dl></div><div class='xr-var-data'><pre>array([&#x27;1991-01-01T00:00:00.000000000&#x27;, &#x27;1991-02-01T00:00:00.000000000&#x27;,
           &#x27;1991-03-01T00:00:00.000000000&#x27;, ..., &#x27;2022-10-01T00:00:00.000000000&#x27;,
           &#x27;2022-11-01T00:00:00.000000000&#x27;, &#x27;2022-12-01T00:00:00.000000000&#x27;],
          dtype=&#x27;datetime64[ns]&#x27;)</pre></div></li></ul></div></li><li class='xr-section-item'><input id='section-9b8338e5-8916-41ec-80e7-23ee83d7981a' class='xr-section-summary-in' type='checkbox'  checked><label for='section-9b8338e5-8916-41ec-80e7-23ee83d7981a' class='xr-section-summary' >Data variables: <span>(4)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-var-name'><span>sm</span></div><div class='xr-var-dims'>(time, lat, lon)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;</div><input id='attrs-ee52ee1b-2389-4af5-b6dc-c89936048517' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-ee52ee1b-2389-4af5-b6dc-c89936048517' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-18354d5f-531c-4307-bc8c-b1eefcca3507' class='xr-var-data-in' type='checkbox'><label for='data-18354d5f-531c-4307-bc8c-b1eefcca3507' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>dtype :</span></dt><dd>float32</dd><dt><span>units :</span></dt><dd>m3 m-3</dd><dt><span>valid_range :</span></dt><dd>[0. 1.]</dd><dt><span>long_name :</span></dt><dd>Volumetric Soil Moisture</dd><dt><span>_CoordinateAxes :</span></dt><dd>time lat lon</dd></dl></div><div class='xr-var-data'><table>
        <tr>
            <td>
                <table style="border-collapse: collapse;">
                    <thead>
                        <tr>
                            <td> </td>
                            <th> Array </th>
                            <th> Chunk </th>
                        </tr>
                    </thead>
                    <tbody>
    
                        <tr>
                            <th> Bytes </th>
                            <td> 45.42 MiB </td>
                            <td> 121.12 kiB </td>
                        </tr>
    
                        <tr>
                            <th> Shape </th>
                            <td> (384, 152, 204) </td>
                            <td> (1, 152, 204) </td>
                        </tr>
                        <tr>
                            <th> Dask graph </th>
                            <td colspan="2"> 384 chunks in 769 graph layers </td>
                        </tr>
                        <tr>
                            <th> Data type </th>
                            <td colspan="2"> float32 numpy.ndarray </td>
                        </tr>
                    </tbody>
                </table>
            </td>
            <td>
            <svg width="194" height="168" style="stroke:rgb(0,0,0);stroke-width:1" >
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="10" y1="47" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="10" y2="47" style="stroke-width:2" />
      <line x1="13" y1="3" x2="13" y2="51" />
      <line x1="17" y1="7" x2="17" y2="54" />
      <line x1="21" y1="11" x2="21" y2="58" />
      <line x1="24" y1="14" x2="24" y2="62" />
      <line x1="28" y1="18" x2="28" y2="66" />
      <line x1="32" y1="22" x2="32" y2="69" />
      <line x1="35" y1="25" x2="35" y2="73" />
      <line x1="39" y1="29" x2="39" y2="77" />
      <line x1="43" y1="33" x2="43" y2="80" />
      <line x1="47" y1="37" x2="47" y2="84" />
      <line x1="50" y1="40" x2="50" y2="88" />
      <line x1="54" y1="44" x2="54" y2="91" />
      <line x1="58" y1="48" x2="58" y2="95" />
      <line x1="61" y1="51" x2="61" y2="99" />
      <line x1="65" y1="55" x2="65" y2="103" />
      <line x1="69" y1="59" x2="69" y2="106" />
      <line x1="73" y1="63" x2="73" y2="110" />
      <line x1="76" y1="66" x2="76" y2="114" />
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 80.58823529411765,70.58823529411765 80.58823529411765,118.08823529411765 10.0,47.5" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="73" y2="0" style="stroke-width:2" />
      <line x1="13" y1="3" x2="77" y2="3" />
      <line x1="17" y1="7" x2="81" y2="7" />
      <line x1="21" y1="11" x2="84" y2="11" />
      <line x1="24" y1="14" x2="88" y2="14" />
      <line x1="28" y1="18" x2="92" y2="18" />
      <line x1="32" y1="22" x2="95" y2="22" />
      <line x1="35" y1="25" x2="99" y2="25" />
      <line x1="39" y1="29" x2="103" y2="29" />
      <line x1="43" y1="33" x2="107" y2="33" />
      <line x1="47" y1="37" x2="110" y2="37" />
      <line x1="50" y1="40" x2="114" y2="40" />
      <line x1="54" y1="44" x2="118" y2="44" />
      <line x1="58" y1="48" x2="121" y2="48" />
      <line x1="61" y1="51" x2="125" y2="51" />
      <line x1="65" y1="55" x2="129" y2="55" />
      <line x1="69" y1="59" x2="133" y2="59" />
      <line x1="73" y1="63" x2="136" y2="63" />
      <line x1="76" y1="66" x2="140" y2="66" />
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="73" y1="0" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 73.75,0.0 144.33823529411765,70.58823529411765 80.58823529411765,70.58823529411765" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
      <line x1="80" y1="118" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
      <line x1="144" y1="70" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="80.58823529411765,70.58823529411765 144.33823529411765,70.58823529411765 144.33823529411765,118.08823529411765 80.58823529411765,118.08823529411765" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Text -->
      <text x="112.463235" y="138.088235" font-size="1.0rem" font-weight="100" text-anchor="middle" >204</text>
      <text x="164.338235" y="94.338235" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(-90,164.338235,94.338235)">152</text>
      <text x="35.294118" y="102.794118" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(45,35.294118,102.794118)">384</text>
    </svg>
            </td>
        </tr>
    </table></div></li><li class='xr-var-item'><div class='xr-var-name'><span>sensor</span></div><div class='xr-var-dims'>(time, lat, lon)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;</div><input id='attrs-0d66f62e-7775-4eca-ad74-456c753cc1ef' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-0d66f62e-7775-4eca-ad74-456c753cc1ef' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-cab35b36-1eb2-41b2-89c1-b878a4a7ae20' class='xr-var-data-in' type='checkbox'><label for='data-cab35b36-1eb2-41b2-89c1-b878a4a7ae20' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>dtype :</span></dt><dd>int16</dd><dt><span>long_name :</span></dt><dd>Sensor</dd><dt><span>_CoordinateAxes :</span></dt><dd>time lat lon</dd><dt><span>flag_values :</span></dt><dd>[0 2]</dd><dt><span>flag_meanings :</span></dt><dd>[&#x27;NaN&#x27;, &#x27;SSMI&#x27;]</dd><dt><span>valid_range :</span></dt><dd>[    0 16383]</dd></dl></div><div class='xr-var-data'><table>
        <tr>
            <td>
                <table style="border-collapse: collapse;">
                    <thead>
                        <tr>
                            <td> </td>
                            <th> Array </th>
                            <th> Chunk </th>
                        </tr>
                    </thead>
                    <tbody>
    
                        <tr>
                            <th> Bytes </th>
                            <td> 45.42 MiB </td>
                            <td> 121.12 kiB </td>
                        </tr>
    
                        <tr>
                            <th> Shape </th>
                            <td> (384, 152, 204) </td>
                            <td> (1, 152, 204) </td>
                        </tr>
                        <tr>
                            <th> Dask graph </th>
                            <td colspan="2"> 384 chunks in 769 graph layers </td>
                        </tr>
                        <tr>
                            <th> Data type </th>
                            <td colspan="2"> float32 numpy.ndarray </td>
                        </tr>
                    </tbody>
                </table>
            </td>
            <td>
            <svg width="194" height="168" style="stroke:rgb(0,0,0);stroke-width:1" >
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="10" y1="47" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="10" y2="47" style="stroke-width:2" />
      <line x1="13" y1="3" x2="13" y2="51" />
      <line x1="17" y1="7" x2="17" y2="54" />
      <line x1="21" y1="11" x2="21" y2="58" />
      <line x1="24" y1="14" x2="24" y2="62" />
      <line x1="28" y1="18" x2="28" y2="66" />
      <line x1="32" y1="22" x2="32" y2="69" />
      <line x1="35" y1="25" x2="35" y2="73" />
      <line x1="39" y1="29" x2="39" y2="77" />
      <line x1="43" y1="33" x2="43" y2="80" />
      <line x1="47" y1="37" x2="47" y2="84" />
      <line x1="50" y1="40" x2="50" y2="88" />
      <line x1="54" y1="44" x2="54" y2="91" />
      <line x1="58" y1="48" x2="58" y2="95" />
      <line x1="61" y1="51" x2="61" y2="99" />
      <line x1="65" y1="55" x2="65" y2="103" />
      <line x1="69" y1="59" x2="69" y2="106" />
      <line x1="73" y1="63" x2="73" y2="110" />
      <line x1="76" y1="66" x2="76" y2="114" />
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 80.58823529411765,70.58823529411765 80.58823529411765,118.08823529411765 10.0,47.5" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="73" y2="0" style="stroke-width:2" />
      <line x1="13" y1="3" x2="77" y2="3" />
      <line x1="17" y1="7" x2="81" y2="7" />
      <line x1="21" y1="11" x2="84" y2="11" />
      <line x1="24" y1="14" x2="88" y2="14" />
      <line x1="28" y1="18" x2="92" y2="18" />
      <line x1="32" y1="22" x2="95" y2="22" />
      <line x1="35" y1="25" x2="99" y2="25" />
      <line x1="39" y1="29" x2="103" y2="29" />
      <line x1="43" y1="33" x2="107" y2="33" />
      <line x1="47" y1="37" x2="110" y2="37" />
      <line x1="50" y1="40" x2="114" y2="40" />
      <line x1="54" y1="44" x2="118" y2="44" />
      <line x1="58" y1="48" x2="121" y2="48" />
      <line x1="61" y1="51" x2="125" y2="51" />
      <line x1="65" y1="55" x2="129" y2="55" />
      <line x1="69" y1="59" x2="133" y2="59" />
      <line x1="73" y1="63" x2="136" y2="63" />
      <line x1="76" y1="66" x2="140" y2="66" />
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="73" y1="0" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 73.75,0.0 144.33823529411765,70.58823529411765 80.58823529411765,70.58823529411765" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
      <line x1="80" y1="118" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
      <line x1="144" y1="70" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="80.58823529411765,70.58823529411765 144.33823529411765,70.58823529411765 144.33823529411765,118.08823529411765 80.58823529411765,118.08823529411765" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Text -->
      <text x="112.463235" y="138.088235" font-size="1.0rem" font-weight="100" text-anchor="middle" >204</text>
      <text x="164.338235" y="94.338235" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(-90,164.338235,94.338235)">152</text>
      <text x="35.294118" y="102.794118" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(45,35.294118,102.794118)">384</text>
    </svg>
            </td>
        </tr>
    </table></div></li><li class='xr-var-item'><div class='xr-var-name'><span>freqbandID</span></div><div class='xr-var-dims'>(time, lat, lon)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;</div><input id='attrs-83d7a94d-7315-401c-bd9f-0097bb748a19' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-83d7a94d-7315-401c-bd9f-0097bb748a19' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-d82f4ee7-8939-4f47-ae3f-0c269d490a22' class='xr-var-data-in' type='checkbox'><label for='data-d82f4ee7-8939-4f47-ae3f-0c269d490a22' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>dtype :</span></dt><dd>int16</dd><dt><span>long_name :</span></dt><dd>Frequency Band Identification</dd><dt><span>_CoordinateAxes :</span></dt><dd>time lat lon</dd><dt><span>flag_values :</span></dt><dd>[  0 128]</dd><dt><span>flag_meanings :</span></dt><dd>[&#x27;NaN&#x27;, &#x27;K194&#x27;]</dd><dt><span>valid_range :</span></dt><dd>[  0 511]</dd></dl></div><div class='xr-var-data'><table>
        <tr>
            <td>
                <table style="border-collapse: collapse;">
                    <thead>
                        <tr>
                            <td> </td>
                            <th> Array </th>
                            <th> Chunk </th>
                        </tr>
                    </thead>
                    <tbody>
    
                        <tr>
                            <th> Bytes </th>
                            <td> 45.42 MiB </td>
                            <td> 121.12 kiB </td>
                        </tr>
    
                        <tr>
                            <th> Shape </th>
                            <td> (384, 152, 204) </td>
                            <td> (1, 152, 204) </td>
                        </tr>
                        <tr>
                            <th> Dask graph </th>
                            <td colspan="2"> 384 chunks in 769 graph layers </td>
                        </tr>
                        <tr>
                            <th> Data type </th>
                            <td colspan="2"> float32 numpy.ndarray </td>
                        </tr>
                    </tbody>
                </table>
            </td>
            <td>
            <svg width="194" height="168" style="stroke:rgb(0,0,0);stroke-width:1" >
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="10" y1="47" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="10" y2="47" style="stroke-width:2" />
      <line x1="13" y1="3" x2="13" y2="51" />
      <line x1="17" y1="7" x2="17" y2="54" />
      <line x1="21" y1="11" x2="21" y2="58" />
      <line x1="24" y1="14" x2="24" y2="62" />
      <line x1="28" y1="18" x2="28" y2="66" />
      <line x1="32" y1="22" x2="32" y2="69" />
      <line x1="35" y1="25" x2="35" y2="73" />
      <line x1="39" y1="29" x2="39" y2="77" />
      <line x1="43" y1="33" x2="43" y2="80" />
      <line x1="47" y1="37" x2="47" y2="84" />
      <line x1="50" y1="40" x2="50" y2="88" />
      <line x1="54" y1="44" x2="54" y2="91" />
      <line x1="58" y1="48" x2="58" y2="95" />
      <line x1="61" y1="51" x2="61" y2="99" />
      <line x1="65" y1="55" x2="65" y2="103" />
      <line x1="69" y1="59" x2="69" y2="106" />
      <line x1="73" y1="63" x2="73" y2="110" />
      <line x1="76" y1="66" x2="76" y2="114" />
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 80.58823529411765,70.58823529411765 80.58823529411765,118.08823529411765 10.0,47.5" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="73" y2="0" style="stroke-width:2" />
      <line x1="13" y1="3" x2="77" y2="3" />
      <line x1="17" y1="7" x2="81" y2="7" />
      <line x1="21" y1="11" x2="84" y2="11" />
      <line x1="24" y1="14" x2="88" y2="14" />
      <line x1="28" y1="18" x2="92" y2="18" />
      <line x1="32" y1="22" x2="95" y2="22" />
      <line x1="35" y1="25" x2="99" y2="25" />
      <line x1="39" y1="29" x2="103" y2="29" />
      <line x1="43" y1="33" x2="107" y2="33" />
      <line x1="47" y1="37" x2="110" y2="37" />
      <line x1="50" y1="40" x2="114" y2="40" />
      <line x1="54" y1="44" x2="118" y2="44" />
      <line x1="58" y1="48" x2="121" y2="48" />
      <line x1="61" y1="51" x2="125" y2="51" />
      <line x1="65" y1="55" x2="129" y2="55" />
      <line x1="69" y1="59" x2="133" y2="59" />
      <line x1="73" y1="63" x2="136" y2="63" />
      <line x1="76" y1="66" x2="140" y2="66" />
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="73" y1="0" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 73.75,0.0 144.33823529411765,70.58823529411765 80.58823529411765,70.58823529411765" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
      <line x1="80" y1="118" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
      <line x1="144" y1="70" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="80.58823529411765,70.58823529411765 144.33823529411765,70.58823529411765 144.33823529411765,118.08823529411765 80.58823529411765,118.08823529411765" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Text -->
      <text x="112.463235" y="138.088235" font-size="1.0rem" font-weight="100" text-anchor="middle" >204</text>
      <text x="164.338235" y="94.338235" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(-90,164.338235,94.338235)">152</text>
      <text x="35.294118" y="102.794118" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(45,35.294118,102.794118)">384</text>
    </svg>
            </td>
        </tr>
    </table></div></li><li class='xr-var-item'><div class='xr-var-name'><span>nobs</span></div><div class='xr-var-dims'>(time, lat, lon)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;</div><input id='attrs-d2e0b77a-ced2-4ff6-8176-0d7b6a3de8a3' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-d2e0b77a-ced2-4ff6-8176-0d7b6a3de8a3' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-9ade5323-779b-494b-b831-1a72751e8bbc' class='xr-var-data-in' type='checkbox'><label for='data-9ade5323-779b-494b-b831-1a72751e8bbc' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>long_name :</span></dt><dd>Number of valid observation</dd><dt><span>CoordinateAxes :</span></dt><dd>time lat lon</dd></dl></div><div class='xr-var-data'><table>
        <tr>
            <td>
                <table style="border-collapse: collapse;">
                    <thead>
                        <tr>
                            <td> </td>
                            <th> Array </th>
                            <th> Chunk </th>
                        </tr>
                    </thead>
                    <tbody>
    
                        <tr>
                            <th> Bytes </th>
                            <td> 45.42 MiB </td>
                            <td> 121.12 kiB </td>
                        </tr>
    
                        <tr>
                            <th> Shape </th>
                            <td> (384, 152, 204) </td>
                            <td> (1, 152, 204) </td>
                        </tr>
                        <tr>
                            <th> Dask graph </th>
                            <td colspan="2"> 384 chunks in 769 graph layers </td>
                        </tr>
                        <tr>
                            <th> Data type </th>
                            <td colspan="2"> float32 numpy.ndarray </td>
                        </tr>
                    </tbody>
                </table>
            </td>
            <td>
            <svg width="194" height="168" style="stroke:rgb(0,0,0);stroke-width:1" >
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="10" y1="47" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="10" y2="47" style="stroke-width:2" />
      <line x1="13" y1="3" x2="13" y2="51" />
      <line x1="17" y1="7" x2="17" y2="54" />
      <line x1="21" y1="11" x2="21" y2="58" />
      <line x1="24" y1="14" x2="24" y2="62" />
      <line x1="28" y1="18" x2="28" y2="66" />
      <line x1="32" y1="22" x2="32" y2="69" />
      <line x1="35" y1="25" x2="35" y2="73" />
      <line x1="39" y1="29" x2="39" y2="77" />
      <line x1="43" y1="33" x2="43" y2="80" />
      <line x1="47" y1="37" x2="47" y2="84" />
      <line x1="50" y1="40" x2="50" y2="88" />
      <line x1="54" y1="44" x2="54" y2="91" />
      <line x1="58" y1="48" x2="58" y2="95" />
      <line x1="61" y1="51" x2="61" y2="99" />
      <line x1="65" y1="55" x2="65" y2="103" />
      <line x1="69" y1="59" x2="69" y2="106" />
      <line x1="73" y1="63" x2="73" y2="110" />
      <line x1="76" y1="66" x2="76" y2="114" />
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 80.58823529411765,70.58823529411765 80.58823529411765,118.08823529411765 10.0,47.5" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="73" y2="0" style="stroke-width:2" />
      <line x1="13" y1="3" x2="77" y2="3" />
      <line x1="17" y1="7" x2="81" y2="7" />
      <line x1="21" y1="11" x2="84" y2="11" />
      <line x1="24" y1="14" x2="88" y2="14" />
      <line x1="28" y1="18" x2="92" y2="18" />
      <line x1="32" y1="22" x2="95" y2="22" />
      <line x1="35" y1="25" x2="99" y2="25" />
      <line x1="39" y1="29" x2="103" y2="29" />
      <line x1="43" y1="33" x2="107" y2="33" />
      <line x1="47" y1="37" x2="110" y2="37" />
      <line x1="50" y1="40" x2="114" y2="40" />
      <line x1="54" y1="44" x2="118" y2="44" />
      <line x1="58" y1="48" x2="121" y2="48" />
      <line x1="61" y1="51" x2="125" y2="51" />
      <line x1="65" y1="55" x2="129" y2="55" />
      <line x1="69" y1="59" x2="133" y2="59" />
      <line x1="73" y1="63" x2="136" y2="63" />
      <line x1="76" y1="66" x2="140" y2="66" />
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="80" y2="70" style="stroke-width:2" />
      <line x1="73" y1="0" x2="144" y2="70" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 73.75,0.0 144.33823529411765,70.58823529411765 80.58823529411765,70.58823529411765" style="fill:#8B4903A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="80" y1="70" x2="144" y2="70" style="stroke-width:2" />
      <line x1="80" y1="118" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="80" y1="70" x2="80" y2="118" style="stroke-width:2" />
      <line x1="144" y1="70" x2="144" y2="118" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="80.58823529411765,70.58823529411765 144.33823529411765,70.58823529411765 144.33823529411765,118.08823529411765 80.58823529411765,118.08823529411765" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Text -->
      <text x="112.463235" y="138.088235" font-size="1.0rem" font-weight="100" text-anchor="middle" >204</text>
      <text x="164.338235" y="94.338235" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(-90,164.338235,94.338235)">152</text>
      <text x="35.294118" y="102.794118" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(45,35.294118,102.794118)">384</text>
    </svg>
            </td>
        </tr>
    </table></div></li></ul></div></li><li class='xr-section-item'><input id='section-b596e57a-7c8f-4c80-849e-d87262087e1d' class='xr-section-summary-in' type='checkbox'  ><label for='section-b596e57a-7c8f-4c80-849e-d87262087e1d' class='xr-section-summary' >Indexes: <span>(3)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-index-name'><div>lat</div></div><div class='xr-index-preview'>PandasIndex</div><div></div><input id='index-b1058c39-7365-4080-84d3-1d2e11b78492' class='xr-index-data-in' type='checkbox'/><label for='index-b1058c39-7365-4080-84d3-1d2e11b78492' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Float64Index([71.875, 71.625, 71.375, 71.125, 70.875, 70.625, 70.375, 70.125,
                  69.875, 69.625,
                  ...
                  36.375, 36.125, 35.875, 35.625, 35.375, 35.125, 34.875, 34.625,
                  34.375, 34.125],
                 dtype=&#x27;float64&#x27;, name=&#x27;lat&#x27;, length=152))</pre></div></li><li class='xr-var-item'><div class='xr-index-name'><div>lon</div></div><div class='xr-index-preview'>PandasIndex</div><div></div><input id='index-cc978039-96bb-4794-a2fb-47536bd4b4b0' class='xr-index-data-in' type='checkbox'/><label for='index-cc978039-96bb-4794-a2fb-47536bd4b4b0' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Float64Index([-10.875, -10.625, -10.375, -10.125,  -9.875,  -9.625,  -9.375,
                   -9.125,  -8.875,  -8.625,
                  ...
                   37.625,  37.875,  38.125,  38.375,  38.625,  38.875,  39.125,
                   39.375,  39.625,  39.875],
                 dtype=&#x27;float64&#x27;, name=&#x27;lon&#x27;, length=204))</pre></div></li><li class='xr-var-item'><div class='xr-index-name'><div>time</div></div><div class='xr-index-preview'>PandasIndex</div><div></div><input id='index-b058331c-a24e-4a4d-9fea-35988af12449' class='xr-index-data-in' type='checkbox'/><label for='index-b058331c-a24e-4a4d-9fea-35988af12449' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(DatetimeIndex([&#x27;1991-01-01&#x27;, &#x27;1991-02-01&#x27;, &#x27;1991-03-01&#x27;, &#x27;1991-04-01&#x27;,
                   &#x27;1991-05-01&#x27;, &#x27;1991-06-01&#x27;, &#x27;1991-07-01&#x27;, &#x27;1991-08-01&#x27;,
                   &#x27;1991-09-01&#x27;, &#x27;1991-10-01&#x27;,
                   ...
                   &#x27;2022-03-01&#x27;, &#x27;2022-04-01&#x27;, &#x27;2022-05-01&#x27;, &#x27;2022-06-01&#x27;,
                   &#x27;2022-07-01&#x27;, &#x27;2022-08-01&#x27;, &#x27;2022-09-01&#x27;, &#x27;2022-10-01&#x27;,
                   &#x27;2022-11-01&#x27;, &#x27;2022-12-01&#x27;],
                  dtype=&#x27;datetime64[ns]&#x27;, name=&#x27;time&#x27;, length=384, freq=None))</pre></div></li></ul></div></li><li class='xr-section-item'><input id='section-603069fb-6d60-4ef3-b869-39303ba0d6df' class='xr-section-summary-in' type='checkbox'  ><label for='section-603069fb-6d60-4ef3-b869-39303ba0d6df' class='xr-section-summary' >Attributes: <span>(40)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><dl class='xr-attrs'><dt><span>title :</span></dt><dd>C3S Surface Soil Moisture merged PASSIVE Product</dd><dt><span>institution :</span></dt><dd>EODC (AUT); TU Wien (AUT); VanderSat B.V. (NL)</dd><dt><span>contact :</span></dt><dd>C3S_SM_Science@eodc.eu</dd><dt><span>source :</span></dt><dd>LPRMv6/SMMR/Nimbus 7 L3 Surface Soil Moisture, Ancillary Params, and quality flags; LPRMv6/SSMI/F08, F11, F13 DMSP L3 Surface Soil Moisture, Ancillary Params, and quality flags; LPRMv6/TMI/TRMM L2 Surface Soil Moisture, Ancillary Params, and QC; LPRMv6/AMSR-E/Aqua L2B Surface Soil Moisture, Ancillary Params, and QC; LPRMv6/WINDSAT/CORIOLIS L2 Surface Soil Moisture, Ancillary Params, and QC; LPRMv6/AMSR2/GCOM-W1 L3 Surface Soil Moisture, Ancillary Params; LPRMv6/SMOS/MIRAS L3 Surface Soil Moisture, CATDS Level 3 Brightness Temperatures (L3TB) version 300 RE03 &amp; RE04; LPRMv6/SMAP_radiometer/SMAP L2 Surface Soil Moisture, Ancillary Params, and QC;</dd><dt><span>platform :</span></dt><dd>Nimbus 7, DMSP, TRMM, AQUA, Coriolis, GCOM-W1, MIRAS, SMAP</dd><dt><span>sensor :</span></dt><dd>SMMR, SSM/I, TMI, AMSR-E, WindSat, AMSR2, SMOS, SMAP_radiometer</dd><dt><span>references :</span></dt><dd>https://climate.copernicus.eu/; Dorigo, W.A., Wagner, W., Albergel, C., Albrecht, F.,  Balsamo, G., Brocca, L., Chung, D., Ertl, M., Forkel, M., Gruber, A., Haas, E., Hamer, D. P. Hirschi, M., Ikonen, J., De Jeu, R. Kidd, R. Lahoz, W., Liu, Y.Y., Miralles, D., Lecomte, P. (2017) ESA CCI Soil Moisture for improved Earth system understanding: State-of-the art and future directions. In Remote Sensing of Environment, 2017, ISSN 0034-4257, https://doi.org/10.1016/j.rse.2017.07.001; Gruber, A., Scanlon, T., van der Schalie, R., Wagner, W., Dorigo, W. (2019) Evolution of the ESA CCI Soil Moisture Climate Data Records and their underlying merging methodology. Earth System Science Data 11, 717-739, https://doi.org/10.5194/essd-11-717-2019; Gruber, A., Dorigo, W. A., Crow, W., Wagner W. (2017). Triple Collocation-Based Merging of Satellite Soil Moisture Retrievals. IEEE Transactions on Geoscience and Remote Sensing. PP. 1-13. https://doi.org/10.1109/TGRS.2017.2734070</dd><dt><span>product_version :</span></dt><dd>v202012</dd><dt><span>tracking_id :</span></dt><dd>544b60cc-22aa-4d83-bef2-32e653cdd226</dd><dt><span>Conventions :</span></dt><dd>CF-1.7</dd><dt><span>standard_name_vocabulary :</span></dt><dd>NetCDF Climate and Forecast (CF) Metadata Convention</dd><dt><span>summary :</span></dt><dd>The data set was produced with funding from the Copernicus Climate Change Service.</dd><dt><span>keywords :</span></dt><dd>Soil Moisture/Water Content</dd><dt><span>naming_authority :</span></dt><dd>EODC GmbH</dd><dt><span>keywords_vocabulary :</span></dt><dd>NASA Global Change Master Directory (GCMD) Science Keywords</dd><dt><span>cdm_data_type :</span></dt><dd>Grid</dd><dt><span>comment :</span></dt><dd>These data were produced as part of the Copernicus Climate Change Service. Service Contract No 2018/C3S_312b_LOT4_EODC/SC2</dd><dt><span>creator_name :</span></dt><dd>Earth Observation Data Center (EODC)</dd><dt><span>creator_url :</span></dt><dd>https://www.eodc.eu</dd><dt><span>creator_email :</span></dt><dd>C3S_SM_Science@eodc.eu</dd><dt><span>project :</span></dt><dd>Copernicus Climate Change Service.</dd><dt><span>license :</span></dt><dd>Copernicus Data License</dd><dt><span>time_coverage_resolution :</span></dt><dd>P1D</dd><dt><span>geospatial_lat_min :</span></dt><dd>-90.0</dd><dt><span>geospatial_lat_max :</span></dt><dd>90.0</dd><dt><span>geospatial_lon_min :</span></dt><dd>-180.0</dd><dt><span>geospatial_lon_max :</span></dt><dd>180.0</dd><dt><span>geospatial_vertical_min :</span></dt><dd>0.0</dd><dt><span>geospatial_vertical_max :</span></dt><dd>0.0</dd><dt><span>geospatial_lat_units :</span></dt><dd>degrees_north</dd><dt><span>geospatial_lon_units :</span></dt><dd>degrees_east</dd><dt><span>geospatial_lat_resolution :</span></dt><dd>0.25 degree</dd><dt><span>geospatial_lon_resolution :</span></dt><dd>0.25 degree</dd><dt><span>spatial_resolution :</span></dt><dd>25km</dd><dt><span>id :</span></dt><dd>C3S-SOILMOISTURE-L3S-SSMV-PASSIVE-MONTHLY-19910101000000-TCDR-v202012.0.0.nc</dd><dt><span>history :</span></dt><dd>2021-03-29T13:46:57.630282 mean calculated</dd><dt><span>date_created :</span></dt><dd>2021-03-29T13:46:57Z</dd><dt><span>time_coverage_start :</span></dt><dd>1990-12-31T12:00:00Z</dd><dt><span>time_coverage_end :</span></dt><dd>1991-01-31T12:00:00Z</dd><dt><span>time_coverage_duration :</span></dt><dd>P1M</dd></dl></div></li></ul></div></div>


**Example 1**: Visualize Data
=============================

Now that we have a data cube to work with, we can start by visualizing
some of the soil moisture data. In this first example we create an
interactive map, to show the absolute soil moisture values for a certain
date. In addition we will use this example to define some locations and
study areas we can use in the rest of the notebook and display their
location on the map.

Study areas
-----------

First we define some potential study areas that we can use in the
following examples. Below you can find a list of bounding boxes, plus
one ‘focus point’ in each bounding box. You can add your own study area
to the end of the list. Make sure to pass the coordinates in the correct
order: Each line consists of:

-  A name for the study area
-  WGS84 coordinates of corner points of a bounding box around the study
   area
-  WGS84 coordinates of a single point in the study area

``(<STUDY_AREA_NAME>, ([<BBOX min. Lon.>, <BBOX max. Lon.>, <BBOX min. Lat.>, <BBOX max. Lat.>], [<POINT Lon.>, <POINT Lat.>]))``

.. code:: ipython3

    BBOXES = OrderedDict([
        # (Name, ([min Lon., max Lon., min Lat., max Lat.], [Lon, Lat])),
        ('Balkans', ([16, 29, 36, 45], [24, 42])),
        ('Cental Europe', ([6, 22.5, 46, 51], [15, 49.5])),
        ('France', ([-4.8, 8.4, 42.3, 51], [4, 47])),
        ('Germany', ([6, 15, 47, 55], [9, 50])),
        ('Iberian Peninsula', ([-10, 3.4, 36, 44.4], [-5.4, 41.3])),
        ('Italy', ([7, 19., 36.7, 47.], [14, 42])),
        ('S-UK & N-France', ([-5.65, 2.5, 48, 54], [-1, 52])),
    ])

``DS`` is a
`xarray.Dataset <https://docs.xarray.dev/en/stable/generated/xarray.Dataset.html>`__,
which comes with a lot of functionalities. For example we can create a
simple map visualization of soil moisture and the number of observations
for a certain date. Using `ipython
widgets <https://ipywidgets.readthedocs.io>`__, we can add a slider that
changes the date to plot.

When browsing through the images of different dates, it can be seen that
the number of observations is much larger in later periods of the record
than in earlier ones due to the larger number of available satellite.

We also include a selection for one of the previously defined study
areas. Note that the study area that is finally chosen in this example
is stored in the global variable ``STUDY_AREA``, which is again used
later on in the notebook!

.. code:: ipython3

    STUDY_AREA = None
    
    # Widgets for this example: 
    # 1) Slider to select date to plot, 2) Dropdown field for study area
    dates = [str(pd.to_datetime(t).date()) for t in DS['time'].values]
    slider = widgets.SelectionSlider(options=dates, value=dates[-1], description='Select a date to plot:', 
                                     continuous_update=False, style={'description_width': 'initial'}, 
                                     layout=widgets.Layout(width='40%'))
    area = widgets.Dropdown(options=list(BBOXES.keys()), value='Germany', description='Study Area:')
    
    @widgets.interact(date=slider, area=area)
    def plot_soil_moisture(date: str, area: str):
        """
        Plot the `soil moisture` and `nobs` variable of the previously loaded Dataset. Provide slider
        to switch between different dates.
        """
        fig, axs = plt.subplots(1, 2, figsize=(17, 5), subplot_kw={'projection': ccrs.PlateCarree()})
        
        # Extract and plot soil moisture image for chosen date:
        p_sm = DS['sm'].sel(time=date) \
                       .plot(transform=ccrs.PlateCarree(), ax=axs[0], cmap=utils.CM_SM,
                             cbar_kwargs={'label': f"Soil Moisture [{SM_UNIT}]"})
        axs[0].set_title(f"{date} - Soil Moisture")
        
        # Extract and plot nobs image for chosen date
        if 'nobs' in DS.variables:
            # nobs is only available for monthly and 10-daily data
            p_obs = DS['nobs'].sel(time=date) \
                              .plot(transform=ccrs.PlateCarree(), ax=axs[1], vmax=31, vmin=0, 
                                    cmap=plt.get_cmap('YlGnBu'), cbar_kwargs={'label': 'Days with valid observations'})
            axs[1].set_title(f"{date} - Data coverage")
        else:
            p_obs = None
        
        bbox = BBOXES[area][0]
        point = BBOXES[area][1]
        
        # Add basemape features
        for p in [p_sm, p_obs]:
            if p is None:
                continue
            p.axes.add_feature(cartopy.feature.LAND, zorder=0, facecolor='gray')
            p.axes.coastlines()
    
        # Add study areas to first map
        axs[0].plot([point[0]], [point[1]], color='red', marker='X', markersize=10, transform=ccrs.PlateCarree())
        axs[0].plot([bbox[0], bbox[0], bbox[1], bbox[1], bbox[0]], [bbox[2], bbox[3], bbox[3], bbox[2], bbox[2]],
                color='red', linewidth=3, transform=ccrs.PlateCarree())
        
        for ax in axs:
            if ax is not None:
                gl = ax.gridlines(crs=ccrs.PlateCarree(), draw_labels=True, alpha=0.25)
                gl.right_labe, gl.top_label = False, False
                
        # Set global variable (to access in later examples)
        global STUDY_AREA
        STUDY_AREA = {'name': area, 'bbox': bbox, 'point': point}




.. parsed-literal::

    interactive(children=(SelectionSlider(continuous_update=False, description='Select a date to plot:', index=383…


**Example 2**: Time Series Extraction and Analysis
==================================================

In the following two examples we use study area selected in Example 1.
We use the chosen ‘focus point’ assigned to the study area (marked by
the red X in the first map of the previous example) to extract a time
series from the loaded stack at this location. We then compute the
climatological mean (and standard deviation) for the chosen time series
using the selected reference period. Finally, we subtract the
climatology from the absolute soil moisture to derive a time series of
anomalies. Anomalies therefore indicate the deviation of a single
observation from the average (normal) conditions. A positive anomaly can
be interpreted as “wetter than usual” soil moisture conditions, while a
negative anomaly indicates “drier than usual” states.

There are different ways to express anomalies: 1) **Absolute
Anomalies**: Simply use the difference between the climatology and the
absolute values and therefore have the same unit as the input data. 2)
**Relative Anomalies**: The anoamalies are expressed relative to the
climatology, i.e. in % above / below the expected conditions. 3)
**Z-Scores**: Z-scores are a way of standardising values from different
normal distributions. Z-scores express the number of standard deviations
from the mean of the sample.

.. code:: ipython3

    # Widgets for this example: 
    # 1) Slider to select baseline period, 2) Dropdown field to select anomaly metric
    baseline_sider = widgets.IntRangeSlider(
        min=1991, max=2021, value=[1991, 2020], step=1, style={'description_width': 'initial'},  continuous_update=False,
        description='Climatology reference / baseline period [year from, year to]:', layout=widgets.Layout(width='50%'))
    metric_dropdown = widgets.Dropdown(options=['Absolute Anomalies', 'Relative Anomalies', 'Z-Scores'], value='Absolute Anomalies', 
                                       description='Metric:')
    @widgets.interact(baseline=baseline_sider, metric=metric_dropdown)
    def plot_ts_components(baseline: tuple, metric: str):
        """
        Compute and visualise climatology and anomalies for the loaded soil moisture time series at the study area focus point.
        """
        # Extract data at location
        lon, lat = float(STUDY_AREA['point'][0]), float(STUDY_AREA['point'][1])
        ts = DS['sm'].sel(lon=lon, lat=lat, method='nearest') \
                     .to_pandas()
        
        # Compute scores
        clim_data = ts.loc[f'{baseline[0]}-01-01':f'{baseline[1]}-12-31']
        clim_std = pd.Series(clim_data.groupby(clim_data.index.month).std(), name='climatology_std')      
        clim_mean = pd.Series(clim_data.groupby(clim_data.index.month).mean(), name='climatology')
        
        ts = pd.DataFrame(ts, columns=['sm']).join(on=ts.index.month, other=clim_mean)
        ts['climatology_std'] = ts.join(on=ts.index.month, other=clim_std)['climatology_std']
        ts['abs_anomaly'] = ts['sm'] - ts['climatology']
        ts['rel_anomaly'] = (ts['sm'] - ts['climatology']) / ts['climatology'] * 100
        ts['z_score'] = (ts['sm'] - ts['climatology']) / ts['climatology_std']
        
        # Generate plots
        fig, axs = plt.subplots(3, 1, figsize=(10, 7))
        
        ts['sm'].plot(ax=axs[0], title=f"Soil Moisture at cental point of `{STUDY_AREA['name']}` study area (Lon: {lon} °W, Lat: {lat} °N)", 
                      ylabel=f'SM $[{SM_UNIT}]$', xlabel='Time [year]')
        
        for i, g in clim_data.groupby(clim_data.index.year):
            axs[1].plot(range(1,13), g.values, alpha=0.2)
            
        clim_mean.plot(ax=axs[1], color='blue', title=f'Soil Moisture Climatology at Lon: {lon} °W, Lat: {lat} °N', 
                       ylabel=f'SM $[{SM_UNIT}]$', label='mean')
        clim_std.plot(ax=axs[1], label='std.dev. $\sigma$', xlabel='Time [month]')
        axs[1].legend()
        
        if metric == 'Absolute Anomalies':
            var = 'abs_anomaly'
            ylabel = f'Anomaly $[{SM_UNIT}]$'
        elif metric == 'Relative Anomalies':
            var = 'rel_anomaly'
            ylabel = f'Anomaly $[\%]$'
        elif metric == 'Z-Scores':
            var = 'z_score'
            ylabel = f'Z-score $[\sigma]$'
        else:
            raise NotImplementedError(f"{metric} is not implemented")
                                      
        axs[2].axhline(0, color='k')
        axs[2].fill_between(ts[var].index,ts[var].values,where=ts[var].values>=0, color='blue')
        axs[2].fill_between(ts[var].index,ts[var].values,where=ts[var].values<0, color='red')
        axs[2].set_ylabel(ylabel)
        axs[2].set_xlabel('Time [year]')
        axs[2].set_title(f"Soil Moisture {metric} at Lon: {lon} °W, Lat: {lat} °N")
        
        plt.tight_layout()




.. parsed-literal::

    interactive(children=(IntRangeSlider(value=(1991, 2020), continuous_update=False, description='Climatology ref…


**Example 3**: Anomaly images and change in study area
======================================================

We now compute the the anomalies for the whole image stack (not on a
time series basis as in the previous example). For this we use some of
the functions provided by xarray to group data. As the climatology
reference period we use all data from 1991 to 2020 (standard baseline
period in climate science), but you can of course try a different period
here as well by changing it in the next cell. We then select all
(absolute) soil moisture values in this period and group them by their
month (i.e. all January, February, … values for all years) and compute
the mean for each group. This way we get a stack of 12 images (one for
each month) as indicated by the table.

.. code:: ipython3

    baseline = (1991, 2020)
    baseline_slice = slice(f"{baseline[0]}-01-01", f"{baseline[1]}-12-31")
    CLIM = DS.sel(time=baseline_slice)['sm'].groupby(DS.sel(time=baseline_slice).time.dt.month).mean()
    
    display(CLIM)



.. raw:: html

    <div><svg style="position: absolute; width: 0; height: 0; overflow: hidden">
    <defs>
    <symbol id="icon-database" viewBox="0 0 32 32">
    <path d="M16 0c-8.837 0-16 2.239-16 5v4c0 2.761 7.163 5 16 5s16-2.239 16-5v-4c0-2.761-7.163-5-16-5z"></path>
    <path d="M16 17c-8.837 0-16-2.239-16-5v6c0 2.761 7.163 5 16 5s16-2.239 16-5v-6c0 2.761-7.163 5-16 5z"></path>
    <path d="M16 26c-8.837 0-16-2.239-16-5v6c0 2.761 7.163 5 16 5s16-2.239 16-5v-6c0 2.761-7.163 5-16 5z"></path>
    </symbol>
    <symbol id="icon-file-text2" viewBox="0 0 32 32">
    <path d="M28.681 7.159c-0.694-0.947-1.662-2.053-2.724-3.116s-2.169-2.030-3.116-2.724c-1.612-1.182-2.393-1.319-2.841-1.319h-15.5c-1.378 0-2.5 1.121-2.5 2.5v27c0 1.378 1.122 2.5 2.5 2.5h23c1.378 0 2.5-1.122 2.5-2.5v-19.5c0-0.448-0.137-1.23-1.319-2.841zM24.543 5.457c0.959 0.959 1.712 1.825 2.268 2.543h-4.811v-4.811c0.718 0.556 1.584 1.309 2.543 2.268zM28 29.5c0 0.271-0.229 0.5-0.5 0.5h-23c-0.271 0-0.5-0.229-0.5-0.5v-27c0-0.271 0.229-0.5 0.5-0.5 0 0 15.499-0 15.5 0v7c0 0.552 0.448 1 1 1h7v19.5z"></path>
    <path d="M23 26h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
    <path d="M23 22h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
    <path d="M23 18h-14c-0.552 0-1-0.448-1-1s0.448-1 1-1h14c0.552 0 1 0.448 1 1s-0.448 1-1 1z"></path>
    </symbol>
    </defs>
    </svg>
    <style>/* CSS stylesheet for displaying xarray objects in jupyterlab.
     *
     */
    
    :root {
      --xr-font-color0: var(--jp-content-font-color0, rgba(0, 0, 0, 1));
      --xr-font-color2: var(--jp-content-font-color2, rgba(0, 0, 0, 0.54));
      --xr-font-color3: var(--jp-content-font-color3, rgba(0, 0, 0, 0.38));
      --xr-border-color: var(--jp-border-color2, #e0e0e0);
      --xr-disabled-color: var(--jp-layout-color3, #bdbdbd);
      --xr-background-color: var(--jp-layout-color0, white);
      --xr-background-color-row-even: var(--jp-layout-color1, white);
      --xr-background-color-row-odd: var(--jp-layout-color2, #eeeeee);
    }
    
    html[theme=dark],
    body[data-theme=dark],
    body.vscode-dark {
      --xr-font-color0: rgba(255, 255, 255, 1);
      --xr-font-color2: rgba(255, 255, 255, 0.54);
      --xr-font-color3: rgba(255, 255, 255, 0.38);
      --xr-border-color: #1F1F1F;
      --xr-disabled-color: #515151;
      --xr-background-color: #111111;
      --xr-background-color-row-even: #111111;
      --xr-background-color-row-odd: #313131;
    }
    
    .xr-wrap {
      display: block !important;
      min-width: 300px;
      max-width: 700px;
    }
    
    .xr-text-repr-fallback {
      /* fallback to plain text repr when CSS is not injected (untrusted notebook) */
      display: none;
    }
    
    .xr-header {
      padding-top: 6px;
      padding-bottom: 6px;
      margin-bottom: 4px;
      border-bottom: solid 1px var(--xr-border-color);
    }
    
    .xr-header > div,
    .xr-header > ul {
      display: inline;
      margin-top: 0;
      margin-bottom: 0;
    }
    
    .xr-obj-type,
    .xr-array-name {
      margin-left: 2px;
      margin-right: 10px;
    }
    
    .xr-obj-type {
      color: var(--xr-font-color2);
    }
    
    .xr-sections {
      padding-left: 0 !important;
      display: grid;
      grid-template-columns: 150px auto auto 1fr 20px 20px;
    }
    
    .xr-section-item {
      display: contents;
    }
    
    .xr-section-item input {
      display: none;
    }
    
    .xr-section-item input + label {
      color: var(--xr-disabled-color);
    }
    
    .xr-section-item input:enabled + label {
      cursor: pointer;
      color: var(--xr-font-color2);
    }
    
    .xr-section-item input:enabled + label:hover {
      color: var(--xr-font-color0);
    }
    
    .xr-section-summary {
      grid-column: 1;
      color: var(--xr-font-color2);
      font-weight: 500;
    }
    
    .xr-section-summary > span {
      display: inline-block;
      padding-left: 0.5em;
    }
    
    .xr-section-summary-in:disabled + label {
      color: var(--xr-font-color2);
    }
    
    .xr-section-summary-in + label:before {
      display: inline-block;
      content: '►';
      font-size: 11px;
      width: 15px;
      text-align: center;
    }
    
    .xr-section-summary-in:disabled + label:before {
      color: var(--xr-disabled-color);
    }
    
    .xr-section-summary-in:checked + label:before {
      content: '▼';
    }
    
    .xr-section-summary-in:checked + label > span {
      display: none;
    }
    
    .xr-section-summary,
    .xr-section-inline-details {
      padding-top: 4px;
      padding-bottom: 4px;
    }
    
    .xr-section-inline-details {
      grid-column: 2 / -1;
    }
    
    .xr-section-details {
      display: none;
      grid-column: 1 / -1;
      margin-bottom: 5px;
    }
    
    .xr-section-summary-in:checked ~ .xr-section-details {
      display: contents;
    }
    
    .xr-array-wrap {
      grid-column: 1 / -1;
      display: grid;
      grid-template-columns: 20px auto;
    }
    
    .xr-array-wrap > label {
      grid-column: 1;
      vertical-align: top;
    }
    
    .xr-preview {
      color: var(--xr-font-color3);
    }
    
    .xr-array-preview,
    .xr-array-data {
      padding: 0 5px !important;
      grid-column: 2;
    }
    
    .xr-array-data,
    .xr-array-in:checked ~ .xr-array-preview {
      display: none;
    }
    
    .xr-array-in:checked ~ .xr-array-data,
    .xr-array-preview {
      display: inline-block;
    }
    
    .xr-dim-list {
      display: inline-block !important;
      list-style: none;
      padding: 0 !important;
      margin: 0;
    }
    
    .xr-dim-list li {
      display: inline-block;
      padding: 0;
      margin: 0;
    }
    
    .xr-dim-list:before {
      content: '(';
    }
    
    .xr-dim-list:after {
      content: ')';
    }
    
    .xr-dim-list li:not(:last-child):after {
      content: ',';
      padding-right: 5px;
    }
    
    .xr-has-index {
      font-weight: bold;
    }
    
    .xr-var-list,
    .xr-var-item {
      display: contents;
    }
    
    .xr-var-item > div,
    .xr-var-item label,
    .xr-var-item > .xr-var-name span {
      background-color: var(--xr-background-color-row-even);
      margin-bottom: 0;
    }
    
    .xr-var-item > .xr-var-name:hover span {
      padding-right: 5px;
    }
    
    .xr-var-list > li:nth-child(odd) > div,
    .xr-var-list > li:nth-child(odd) > label,
    .xr-var-list > li:nth-child(odd) > .xr-var-name span {
      background-color: var(--xr-background-color-row-odd);
    }
    
    .xr-var-name {
      grid-column: 1;
    }
    
    .xr-var-dims {
      grid-column: 2;
    }
    
    .xr-var-dtype {
      grid-column: 3;
      text-align: right;
      color: var(--xr-font-color2);
    }
    
    .xr-var-preview {
      grid-column: 4;
    }
    
    .xr-index-preview {
      grid-column: 2 / 5;
      color: var(--xr-font-color2);
    }
    
    .xr-var-name,
    .xr-var-dims,
    .xr-var-dtype,
    .xr-preview,
    .xr-attrs dt {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      padding-right: 10px;
    }
    
    .xr-var-name:hover,
    .xr-var-dims:hover,
    .xr-var-dtype:hover,
    .xr-attrs dt:hover {
      overflow: visible;
      width: auto;
      z-index: 1;
    }
    
    .xr-var-attrs,
    .xr-var-data,
    .xr-index-data {
      display: none;
      background-color: var(--xr-background-color) !important;
      padding-bottom: 5px !important;
    }
    
    .xr-var-attrs-in:checked ~ .xr-var-attrs,
    .xr-var-data-in:checked ~ .xr-var-data,
    .xr-index-data-in:checked ~ .xr-index-data {
      display: block;
    }
    
    .xr-var-data > table {
      float: right;
    }
    
    .xr-var-name span,
    .xr-var-data,
    .xr-index-name div,
    .xr-index-data,
    .xr-attrs {
      padding-left: 25px !important;
    }
    
    .xr-attrs,
    .xr-var-attrs,
    .xr-var-data,
    .xr-index-data {
      grid-column: 1 / -1;
    }
    
    dl.xr-attrs {
      padding: 0;
      margin: 0;
      display: grid;
      grid-template-columns: 125px auto;
    }
    
    .xr-attrs dt,
    .xr-attrs dd {
      padding: 0;
      margin: 0;
      float: left;
      padding-right: 10px;
      width: auto;
    }
    
    .xr-attrs dt {
      font-weight: normal;
      grid-column: 1;
    }
    
    .xr-attrs dt:hover span {
      display: inline-block;
      background: var(--xr-background-color);
      padding-right: 10px;
    }
    
    .xr-attrs dd {
      grid-column: 2;
      white-space: pre-wrap;
      word-break: break-all;
    }
    
    .xr-icon-database,
    .xr-icon-file-text2,
    .xr-no-icon {
      display: inline-block;
      vertical-align: middle;
      width: 1em;
      height: 1.5em !important;
      stroke-width: 0;
      stroke: currentColor;
      fill: currentColor;
    }
    </style><pre class='xr-text-repr-fallback'>&lt;xarray.DataArray &#x27;sm&#x27; (month: 12, lat: 152, lon: 204)&gt;
    dask.array&lt;stack, shape=(12, 152, 204), dtype=float32, chunksize=(1, 152, 204), chunktype=numpy.ndarray&gt;
    Coordinates:
      * lat      (lat) float32 71.88 71.62 71.38 71.12 ... 34.88 34.62 34.38 34.12
      * lon      (lon) float32 -10.88 -10.62 -10.38 -10.12 ... 39.38 39.62 39.88
      * month    (month) int64 1 2 3 4 5 6 7 8 9 10 11 12
    Attributes:
        dtype:            float32
        units:            m3 m-3
        valid_range:      [0. 1.]
        long_name:        Volumetric Soil Moisture
        _CoordinateAxes:  time lat lon</pre><div class='xr-wrap' style='display:none'><div class='xr-header'><div class='xr-obj-type'>xarray.DataArray</div><div class='xr-array-name'>'sm'</div><ul class='xr-dim-list'><li><span class='xr-has-index'>month</span>: 12</li><li><span class='xr-has-index'>lat</span>: 152</li><li><span class='xr-has-index'>lon</span>: 204</li></ul></div><ul class='xr-sections'><li class='xr-section-item'><div class='xr-array-wrap'><input id='section-c50e5c57-b1f8-4b5d-bf6b-b59a5f165f27' class='xr-array-in' type='checkbox' checked><label for='section-c50e5c57-b1f8-4b5d-bf6b-b59a5f165f27' title='Show/hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-array-preview xr-preview'><span>dask.array&lt;chunksize=(1, 152, 204), meta=np.ndarray&gt;</span></div><div class='xr-array-data'><table>
        <tr>
            <td>
                <table style="border-collapse: collapse;">
                    <thead>
                        <tr>
                            <td> </td>
                            <th> Array </th>
                            <th> Chunk </th>
                        </tr>
                    </thead>
                    <tbody>
    
                        <tr>
                            <th> Bytes </th>
                            <td> 1.42 MiB </td>
                            <td> 121.12 kiB </td>
                        </tr>
    
                        <tr>
                            <th> Shape </th>
                            <td> (12, 152, 204) </td>
                            <td> (1, 152, 204) </td>
                        </tr>
                        <tr>
                            <th> Dask graph </th>
                            <td colspan="2"> 12 chunks in 831 graph layers </td>
                        </tr>
                        <tr>
                            <th> Data type </th>
                            <td colspan="2"> float32 numpy.ndarray </td>
                        </tr>
                    </tbody>
                </table>
            </td>
            <td>
            <svg width="200" height="160" style="stroke:rgb(0,0,0);stroke-width:1" >
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="30" y2="20" style="stroke-width:2" />
      <line x1="10" y1="89" x2="30" y2="110" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="10" y2="89" style="stroke-width:2" />
      <line x1="11" y1="1" x2="11" y2="91" />
      <line x1="13" y1="3" x2="13" y2="92" />
      <line x1="15" y1="5" x2="15" y2="94" />
      <line x1="16" y1="6" x2="16" y2="96" />
      <line x1="18" y1="8" x2="18" y2="98" />
      <line x1="20" y1="10" x2="20" y2="99" />
      <line x1="22" y1="12" x2="22" y2="101" />
      <line x1="23" y1="13" x2="23" y2="103" />
      <line x1="25" y1="15" x2="25" y2="105" />
      <line x1="27" y1="17" x2="27" y2="106" />
      <line x1="29" y1="19" x2="29" y2="108" />
      <line x1="30" y1="20" x2="30" y2="110" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 30.877949270298778,20.877949270298778 30.877949270298778,110.28971397618113 10.0,89.41176470588236" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="10" y1="0" x2="130" y2="0" style="stroke-width:2" />
      <line x1="11" y1="1" x2="131" y2="1" />
      <line x1="13" y1="3" x2="133" y2="3" />
      <line x1="15" y1="5" x2="135" y2="5" />
      <line x1="16" y1="6" x2="136" y2="6" />
      <line x1="18" y1="8" x2="138" y2="8" />
      <line x1="20" y1="10" x2="140" y2="10" />
      <line x1="22" y1="12" x2="142" y2="12" />
      <line x1="23" y1="13" x2="143" y2="13" />
      <line x1="25" y1="15" x2="145" y2="15" />
      <line x1="27" y1="17" x2="147" y2="17" />
      <line x1="29" y1="19" x2="149" y2="19" />
      <line x1="30" y1="20" x2="150" y2="20" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="10" y1="0" x2="30" y2="20" style="stroke-width:2" />
      <line x1="130" y1="0" x2="150" y2="20" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="10.0,0.0 130.0,0.0 150.87794927029879,20.877949270298778 30.877949270298778,20.877949270298778" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Horizontal lines -->
      <line x1="30" y1="20" x2="150" y2="20" style="stroke-width:2" />
      <line x1="30" y1="110" x2="150" y2="110" style="stroke-width:2" />
    
      <!-- Vertical lines -->
      <line x1="30" y1="20" x2="30" y2="110" style="stroke-width:2" />
      <line x1="150" y1="20" x2="150" y2="110" style="stroke-width:2" />
    
      <!-- Colored Rectangle -->
      <polygon points="30.877949270298778,20.877949270298778 150.87794927029879,20.877949270298778 150.87794927029879,110.28971397618113 30.877949270298778,110.28971397618113" style="fill:#ECB172A0;stroke-width:0"/>
    
      <!-- Text -->
      <text x="90.877949" y="130.289714" font-size="1.0rem" font-weight="100" text-anchor="middle" >204</text>
      <text x="170.877949" y="65.583832" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(-90,170.877949,65.583832)">152</text>
      <text x="10.438975" y="119.850739" font-size="1.0rem" font-weight="100" text-anchor="middle" transform="rotate(45,10.438975,119.850739)">12</text>
    </svg>
            </td>
        </tr>
    </table></div></div></li><li class='xr-section-item'><input id='section-9468cc0b-1443-470c-b65b-9fcc90b96f10' class='xr-section-summary-in' type='checkbox'  checked><label for='section-9468cc0b-1443-470c-b65b-9fcc90b96f10' class='xr-section-summary' >Coordinates: <span>(3)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>lat</span></div><div class='xr-var-dims'>(lat)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>71.88 71.62 71.38 ... 34.38 34.12</div><input id='attrs-096c3b62-e8c0-40ee-ac4e-924f72e001ad' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-096c3b62-e8c0-40ee-ac4e-924f72e001ad' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-74d659df-77e1-4bb2-ac14-77d2099e5c73' class='xr-var-data-in' type='checkbox'><label for='data-74d659df-77e1-4bb2-ac14-77d2099e5c73' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>standard_name :</span></dt><dd>latitude</dd><dt><span>units :</span></dt><dd>degrees_north</dd><dt><span>valid_range :</span></dt><dd>[-90.  90.]</dd><dt><span>_CoordinateAxisType :</span></dt><dd>Lat</dd></dl></div><div class='xr-var-data'><pre>array([71.875, 71.625, 71.375, 71.125, 70.875, 70.625, 70.375, 70.125, 69.875,
           69.625, 69.375, 69.125, 68.875, 68.625, 68.375, 68.125, 67.875, 67.625,
           67.375, 67.125, 66.875, 66.625, 66.375, 66.125, 65.875, 65.625, 65.375,
           65.125, 64.875, 64.625, 64.375, 64.125, 63.875, 63.625, 63.375, 63.125,
           62.875, 62.625, 62.375, 62.125, 61.875, 61.625, 61.375, 61.125, 60.875,
           60.625, 60.375, 60.125, 59.875, 59.625, 59.375, 59.125, 58.875, 58.625,
           58.375, 58.125, 57.875, 57.625, 57.375, 57.125, 56.875, 56.625, 56.375,
           56.125, 55.875, 55.625, 55.375, 55.125, 54.875, 54.625, 54.375, 54.125,
           53.875, 53.625, 53.375, 53.125, 52.875, 52.625, 52.375, 52.125, 51.875,
           51.625, 51.375, 51.125, 50.875, 50.625, 50.375, 50.125, 49.875, 49.625,
           49.375, 49.125, 48.875, 48.625, 48.375, 48.125, 47.875, 47.625, 47.375,
           47.125, 46.875, 46.625, 46.375, 46.125, 45.875, 45.625, 45.375, 45.125,
           44.875, 44.625, 44.375, 44.125, 43.875, 43.625, 43.375, 43.125, 42.875,
           42.625, 42.375, 42.125, 41.875, 41.625, 41.375, 41.125, 40.875, 40.625,
           40.375, 40.125, 39.875, 39.625, 39.375, 39.125, 38.875, 38.625, 38.375,
           38.125, 37.875, 37.625, 37.375, 37.125, 36.875, 36.625, 36.375, 36.125,
           35.875, 35.625, 35.375, 35.125, 34.875, 34.625, 34.375, 34.125],
          dtype=float32)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>lon</span></div><div class='xr-var-dims'>(lon)</div><div class='xr-var-dtype'>float32</div><div class='xr-var-preview xr-preview'>-10.88 -10.62 ... 39.62 39.88</div><input id='attrs-dd80afd9-558d-4db4-b2a9-4b632384b2ea' class='xr-var-attrs-in' type='checkbox' ><label for='attrs-dd80afd9-558d-4db4-b2a9-4b632384b2ea' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-190c4ff4-6727-45cb-b55f-57914cf42aad' class='xr-var-data-in' type='checkbox'><label for='data-190c4ff4-6727-45cb-b55f-57914cf42aad' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'><dt><span>standard_name :</span></dt><dd>longitude</dd><dt><span>units :</span></dt><dd>degrees_east</dd><dt><span>valid_range :</span></dt><dd>[-180.  180.]</dd><dt><span>_CoordinateAxisType :</span></dt><dd>Lon</dd></dl></div><div class='xr-var-data'><pre>array([-10.875, -10.625, -10.375, ...,  39.375,  39.625,  39.875],
          dtype=float32)</pre></div></li><li class='xr-var-item'><div class='xr-var-name'><span class='xr-has-index'>month</span></div><div class='xr-var-dims'>(month)</div><div class='xr-var-dtype'>int64</div><div class='xr-var-preview xr-preview'>1 2 3 4 5 6 7 8 9 10 11 12</div><input id='attrs-f3790ef5-34a9-4172-9d66-b3d7663ff680' class='xr-var-attrs-in' type='checkbox' disabled><label for='attrs-f3790ef5-34a9-4172-9d66-b3d7663ff680' title='Show/Hide attributes'><svg class='icon xr-icon-file-text2'><use xlink:href='#icon-file-text2'></use></svg></label><input id='data-cf377e32-4727-402d-b4fe-afe7dbedadb3' class='xr-var-data-in' type='checkbox'><label for='data-cf377e32-4727-402d-b4fe-afe7dbedadb3' title='Show/Hide data repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-var-attrs'><dl class='xr-attrs'></dl></div><div class='xr-var-data'><pre>array([ 1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12])</pre></div></li></ul></div></li><li class='xr-section-item'><input id='section-f60bdc3d-d4fc-49ca-944a-b3650be357c5' class='xr-section-summary-in' type='checkbox'  ><label for='section-f60bdc3d-d4fc-49ca-944a-b3650be357c5' class='xr-section-summary' >Indexes: <span>(3)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><ul class='xr-var-list'><li class='xr-var-item'><div class='xr-index-name'><div>lat</div></div><div class='xr-index-preview'>PandasIndex</div><div></div><input id='index-f6988c76-f31a-4d7c-b4e3-71d442c9c504' class='xr-index-data-in' type='checkbox'/><label for='index-f6988c76-f31a-4d7c-b4e3-71d442c9c504' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Float64Index([71.875, 71.625, 71.375, 71.125, 70.875, 70.625, 70.375, 70.125,
                  69.875, 69.625,
                  ...
                  36.375, 36.125, 35.875, 35.625, 35.375, 35.125, 34.875, 34.625,
                  34.375, 34.125],
                 dtype=&#x27;float64&#x27;, name=&#x27;lat&#x27;, length=152))</pre></div></li><li class='xr-var-item'><div class='xr-index-name'><div>lon</div></div><div class='xr-index-preview'>PandasIndex</div><div></div><input id='index-d498541d-51dc-4b2d-9ce2-0fb3d73527d3' class='xr-index-data-in' type='checkbox'/><label for='index-d498541d-51dc-4b2d-9ce2-0fb3d73527d3' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Float64Index([-10.875, -10.625, -10.375, -10.125,  -9.875,  -9.625,  -9.375,
                   -9.125,  -8.875,  -8.625,
                  ...
                   37.625,  37.875,  38.125,  38.375,  38.625,  38.875,  39.125,
                   39.375,  39.625,  39.875],
                 dtype=&#x27;float64&#x27;, name=&#x27;lon&#x27;, length=204))</pre></div></li><li class='xr-var-item'><div class='xr-index-name'><div>month</div></div><div class='xr-index-preview'>PandasIndex</div><div></div><input id='index-2e5458a3-4a2f-4626-8ae7-65d60d7b83c9' class='xr-index-data-in' type='checkbox'/><label for='index-2e5458a3-4a2f-4626-8ae7-65d60d7b83c9' title='Show/Hide index repr'><svg class='icon xr-icon-database'><use xlink:href='#icon-database'></use></svg></label><div class='xr-index-data'><pre>PandasIndex(Int64Index([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], dtype=&#x27;int64&#x27;, name=&#x27;month&#x27;))</pre></div></li></ul></div></li><li class='xr-section-item'><input id='section-93d61dc1-7260-4d56-89c8-127ef6c64943' class='xr-section-summary-in' type='checkbox'  checked><label for='section-93d61dc1-7260-4d56-89c8-127ef6c64943' class='xr-section-summary' >Attributes: <span>(5)</span></label><div class='xr-section-inline-details'></div><div class='xr-section-details'><dl class='xr-attrs'><dt><span>dtype :</span></dt><dd>float32</dd><dt><span>units :</span></dt><dd>m3 m-3</dd><dt><span>valid_range :</span></dt><dd>[0. 1.]</dd><dt><span>long_name :</span></dt><dd>Volumetric Soil Moisture</dd><dt><span>_CoordinateAxes :</span></dt><dd>time lat lon</dd></dl></div></li></ul></div></div>


We can now use the climatology stack and compute the difference between
each image of absolute soil moisture and the climatological mean of the
same month. We assign the result to a new variable in the same stack
called ``sm_anomaly``.

.. code:: ipython3

    %%capture --no-display
    DS['sm_anomaly'] = DS['sm'] - CLIM.sel(month=DS.time.dt.month).drop('month')

We can use the bounding box chosen in the previous example to extract
all soil moisture data in this area. We then compute the mean over all
locations in the bounding box to get a single time series for the study
area. Note that the coverage of C3S Soil Moisture varies over time (see
the first example), which can also affect the value range of computed
anomalies.

.. code:: ipython3

    subset = DS[['sm_anomaly']].sel(lon=slice(STUDY_AREA['bbox'][0], STUDY_AREA['bbox'][1]), 
                                    lat=slice(STUDY_AREA['bbox'][3], STUDY_AREA['bbox'][2]))
    MEAN_TS = subset.mean(dim=['lat', 'lon']).to_pandas()
    STD_TS = subset.std(dim=['lat', 'lon']).to_pandas()

Now we can not only visualize the monthly anomalies for all downloaded
images, but also create a plot of annual mean anomalies in the chosen
study area. We see a overall trend towards drier conditions in most
regions.

.. code:: ipython3

    dates = [str(pd.to_datetime(t).date()) for t in DS['time'].values]
    slider = widgets.SelectionSlider(options=dates, value=dates[-1], description='Select a date to plot (map):', 
                                     continuous_update=False, style={'description_width': 'initial'}, 
                                     layout=widgets.Layout(width='30%'))
    @widgets.interact(date=slider)
    def plot_anomaly(date: str):
        
        STUDY_AREA_TS = pd.DataFrame(MEAN_TS['sm_anomaly']).resample('A').mean()
        STUDY_AREA_TS.index = STUDY_AREA_TS.index.year
    
        fig = plt.figure(figsize=(15,4), constrained_layout=True)
        gs = fig.add_gridspec(1, 3)
        map_ax = fig.add_subplot(gs[0, 0], projection=ccrs.PlateCarree())
        ts_ax = fig.add_subplot(gs[0, 1:])
        
        # Plot overview map
        p_anom = DS['sm_anomaly'].sel(time=date) \
                                 .plot(transform=ccrs.PlateCarree(), ax=map_ax, cmap=plt.get_cmap('RdBu'), 
                                       cbar_kwargs={'label': f"Anomaly [{SM_UNIT}]"})
        map_ax.axes.add_feature(cartopy.feature.LAND, zorder=0, facecolor='gray')
        map_ax.axes.coastlines()
        map_ax.add_feature(cartopy.feature.BORDERS)
        map_ax.set_title(f"{date} - Soil Moisture Anomaly")
        
        # Add study area box to map:
        bbox = STUDY_AREA['bbox']
        map_ax.plot([bbox[0], bbox[0], bbox[1], bbox[1], bbox[0]], [bbox[2], bbox[3], bbox[3], bbox[2], bbox[2]],
                     color='red', linewidth=3, transform=ccrs.PlateCarree())
        gl = map_ax.gridlines(crs=ccrs.PlateCarree(), draw_labels=True, alpha=0.25)
        gl.right_labe, gl.top_label = False, False
        
        # Create the bar plot:
        bars = STUDY_AREA_TS.plot(kind='bar', ax=ts_ax, title=f"Annual conditions in `{STUDY_AREA['name']}` study area", 
                                  legend=False, xlabel='Year', ylabel=f"Anomaly [{SM_UNIT}]")
        bars.axhline(y=0, color='black', linewidth=1)
        
        # Highlight the corresponding bar(s) on the right:
        for i, bar in enumerate(bars.patches):
            year = STUDY_AREA_TS.index.values[i]
            if STUDY_AREA_TS.values[i] > 0:
                bar.set_facecolor('blue')
            else:
                bar.set_facecolor('red')
            if year == pd.to_datetime(date).year:
                bar.set_edgecolor('k')
                bar.set_linewidth(3)



.. parsed-literal::

    interactive(children=(SelectionSlider(continuous_update=False, description='Select a date to plot (map):', ind…

