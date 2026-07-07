/*==============================================================================
  INSTALL USER-WRITTEN STATA DEPENDENCIES
  Run only when internet access is available.
==============================================================================*/

version 17.0
set more off

capture program drop _install_ssc_if_missing
program define _install_ssc_if_missing
    syntax , COMMAND(name) PACKAGE(name)
    capture which `command'
    if _rc {
        noi di as text "Installing `package' from SSC..."
        ssc install `package', replace
    }
    else {
        noi di as text "Found `command'."
    }
end

_install_ssc_if_missing, command(ftools)    package(ftools)
_install_ssc_if_missing, command(reghdfe)   package(reghdfe)
_install_ssc_if_missing, command(ivreg2)    package(ivreg2)
_install_ssc_if_missing, command(prodest)   package(prodest)

capture which ivreghdfe
if _rc {
    noi di as text "Installing ivreghdfe from its official source..."
    net install ivreghdfe, ///
        from("https://raw.githubusercontent.com/sergiocorreia/ivreghdfe/master/src/") replace
}
else {
    noi di as text "Found ivreghdfe."
}

noi di as result "Dependency check completed."
