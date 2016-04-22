# PoshWizard
A simple PowerShell DSL for creating simple Wizards

You can use this module as a simple DSL for creating typical Wizards that contains several pages with input elements like so

Import-Module -Name PoshWizard

Assistant –Title "Create Directory"  {
 Window –Title "Step 1 – Provide path"  {
  Label -Text "The path please:" 
  TextBox –Name Path
  OKButton  { if (Test-Path –Path $Path –IsValid) {  Md $Path  } }
    } -CloseWindow
}

In the current (initial) version there are only two input elements: TextBox and Choice. The action is determined with the OKButton and its ScriptBlock-Parameter.
