<#
 .Synopsis
 A simple DSL for creating wizards
 .Notes
 Last Update:4/22/2016
#>

Import-LocalizedData -BindingVariable Msg -UICulture "de-DE"

# Helper class for finding controls in the logical tree
# by their type
$CSCode = @'
    using System;
    using System.Collections;
    using System.Collections.Generic;
    using System.Windows;
    using System.Windows.Media;
    using System.Windows.Controls;

    namespace Poshwizard
    {
        public class WPFHelper
        {
            // Gets all logical child elements of a certain type
            private static List<T> GetLogicalChildCollection<T>(object parent) where T : DependencyObject
            {
                List<T> logicalCollection = new List<T>();
                GetLogicalChildCollection(parent as DependencyObject, logicalCollection);
                return logicalCollection;
            }

            private static void GetLogicalChildCollection<T>(DependencyObject parent, List<T> logicalCollection) where T : DependencyObject
            {
                IEnumerable children = LogicalTreeHelper.GetChildren(parent);
                foreach (object child in children)
                {
                    if (child is DependencyObject)
                    {
                        DependencyObject depChild = child as DependencyObject;
                        if (child is T)
                        {
                            logicalCollection.Add(child as T);
                        }
                        GetLogicalChildCollection(depChild, logicalCollection);
                    }
                }
            }

            // Gets all Textboxes
            public static List<TextBox> GetTextboxes(Window w)
            {
                List<TextBox> textboxList = GetLogicalChildCollection<TextBox>(w);
                // Console.WriteLine("*** {0} TextBoxes found. ***", textboxList.Count);
                return textboxList;
            }

            // Gets all RadioButtons
            public static List<RadioButton> GetRadioButtons(Window w)
            {
                List<RadioButton> radioButtonList = GetLogicalChildCollection<RadioButton>(w);
                // Console.WriteLine("*** {0} RadioButtons found. ***", radioButtonList.Count);
                return radioButtonList;
            }

            // Gets all Buttons
            public static List<Button> GetButtons(Window w)
            {
                List<Button> buttonList = GetLogicalChildCollection<Button>(w);
                return buttonList;
            }

        }
    }

'@

# Add the custom type into the current PowerShell session
Add-Type -TypeDefinition $CSCode -Language CSharp `
 -ReferencedAssemblies PresentationCore, PresentationFramework, WindowsBase, System.Xaml

<#
 .Synopsis
 Creates an assistant
 .Parameter Title
 The title of the main window
 .Parameter ScriptBlock
 Contains all the window elements
 .Parameter Width
 Window width
 .Parameter Height
 Window height
#>
function Assistant
{
    param([Parameter(Mandatory=$true, Position=1)][String]$Title,
          [Parameter(Mandatory=$true, Position=2)][Scriptblock]$Scriptblock,
          [Parameter(Position=3)][Int]$Width = 800,
          [Parameter(Position=4)][Int]$Height = 600)

    $Script:BackButtonCount = 1
    $Script:NextButtonCount = 1
    $Script:CurrentTabIndex = 0
    $Script:OKButtonCount = 0
    $Script:CloseWindow = $false
    $Script:ErrorFlag = $false
    $Script:SBOKButtonAction = $null
    $Script:WizardVariables = @()
    $Script:LogoPfad = (Join-Path -Path $PSScriptRoot -ChildPath "PoshwizardLogo.png")

    $xaml = "<Window "
    $xaml += "x:Name='MainWindow' "
    $xaml += "xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' "
    $xaml += "xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' "
    $xaml += "Title = '$Title' "
    $xaml += "Width='$Width' "
    $xaml += "Height='$Height' "
    $xaml += "FontFamily='Verdana' "
    $xaml += "FontSize='16' "
    $xaml += "WindowStyle='ToolWindow' "
    $xaml += ">"
    $xaml += "<TabControl "
    $xaml += "Name='MainTabControl' "
    $xaml += ">"
    $xaml += $ScriptBlock.Invoke()
    $xaml += "</TabControl>"
    $xaml += "</Window>"
    # $xaml

    # Executes when a Next button is clicked
    $SBNextButton = {
        param($Sender, $EventArgs)
        # [System.Windows.MessageBox]::Show($CurrentTabIndex)
        [void]($Sender.Name -match "\w+(\d+)")
        $TabIndex = $Matches[1]
        $TabControl.SelectedIndex = $TabIndex
        $Script:CurrentTabIndex = $TabIndex
    }

    # Executes when a Back button is clicked
    $SBBackButton = {
        param($Sender, $EventArgs)
        [void]($Sender.Name -match "\w+(\d+)")
        $TabIndex = [Int]$Matches[1]
        $TabIndex--
        $TabControl.SelectedIndex = $TabIndex
        $Script:CurrentTabIndex = $TabIndex
    }

    # Executes when a Tab page had been selected
    $SBTabSelectionChanged = {
        param($Sender, $EventArgs)
        $Script:CurrentTabIndex = $Sender.SelectedIndex
    }

    # Executes when the content of a Textbox changes
    $SBTextBoxChanged = {
        # Put the current value of the Textbox into the variable with the same name
        param($Sender, $EventArgs)
        $TBName = $Sender.Name
        Set-Variable -Name $TBName -Value $Sender.Text -Scope "Global"
    }

    # Executes when a Radio Button had been selected
    $SBSelectedChanged = {
        param($Sender, $EventArgs)
        # Put the text of the selected RadioButton into the variable with the same name
        # split the numbers and the end of the name
        [void]($Sender.Name -match "^([a-z]+)(\d+)")
        $RadioName = $Matches[1]
        Set-Variable -Name $RadioName -Value $Sender.Content -Scope "Global"
    }

    # Executes when a file choose-Button is clicked
    $SBFileChoose = {
        param($Sender, $EventArgs)
        $OpenFileDlg = New-Object -TypeName Microsoft.Win32.OpenFileDialog
        $OpenFileDlg.InitialDirectory = "$env:userprofile\Documents"
        $OpenFileDlg.Filter = "All Files (*.*)|*.*"
        if ($OpenFileDlg.ShowDialog())
        {
          $VarName = ($Sender.Name -split "_File")[0]
          Set-Variable -Name $VarName -Value $OpenFileDlg.FileName
          # Aktualisieren der entsprechenden TextBox
          $tb = $MainWin.FindName($VarName)
          if ($tb -ne $null)
          {
            $tb.Text = $OpenFileDlg.FileName
          }
        }
    }

    # Creates main window from xaml 
    $MainWin= [System.Windows.Markup.XamlReader]::Parse($Xaml)

    # Setup the event handler for the TabControl
    $Script:TabControl = $MainWin.FindName("MainTabControl")
    $TabControl.add_SelectionChanged($SBTabSelectionChanged)

    # Setup event handlers for all Next Buttons
    $i = 1
    while($true)
    {
      $btnName = "NextButton$i"
      $i++
      $btn = $MainWin.FindName($btnName)
      if ($btn -eq $null)
      { break }
      $btn.Add_Click($SBNextButton)
    }

    # Setup event handlers for all Back buttons
    $i = 1
    while($true)
    {
      $btnName = "BackButton$i"
      $i++
      $btn = $MainWin.FindName($btnName)
      if ($btn -eq $null)
      { break }
      $btn.Add_Click($SBBackButton)
    }

    # Setup ChangedEvent handlers for all TextBoxes
    $TextboxListe = [Poshwizard.WPFHelper]::GetTextboxes($MainWin)
    foreach($Tb in $TextboxListe)
    {
        $Tb.add_TextChanged($SBTextBoxChanged)
    }

    # Setup CheckedEvent handlers for all RadioButtons
    $RadioButtonListe = [Poshwizard.WPFHelper]::GetRadioButtons($MainWin)
    foreach($Rb in $RadioButtonListe)
    {
        $Rb.add_Checked($SBSelectedChanged)
    }

    # Setup event handlers for all FileChoose-Buttons
    $FileChooseButtons =  [Poshwizard.WPFHelper]::GetButtons($MainWin) | Where Name -like "*_File*"
    foreach($Btn in $FileChooseButtons)
    {

        $Btn.add_Click($SBFileChoose)
    }

    # Setup action for the OKButton
    $OKButton = $MainWin.FindName("OKButton")

    # Is a OKButton already there?
    if ($OKButton -eq $null)
    {
        $Script:ErrorFlag = $true
        Write-Error $msg.ErrorMsg2
    }

    $OKButton.add_click($Script:SBOKButtonAction)

    # Additional Action for the Close window parameter
    $SBClose = {
        if ($Script:CloseWindow)
        {
            $MainWin.Close()
        }
    }

    $OKButton.add_click($SBClose)

    # Any errors?
    if (!$Script:ErrorFlag)
    {
        [void]$MainWin.ShowDialog()
    }
    else
    {
        Write-Warning $msg.ErrorMsg1
    }

    # Delete all variables created by the Module
    foreach($v in $Script:WizardVariables)
    {
        rm variable:"$($v.Name)"
    }

}

<#
 .Synopsis
 Legt ein einzelnes Fenster an
 .Parameter Title
 The Window title
 .Parameter Description
 A description that is display on top of the Window display area
 .Parameter ScriptBlock
 Contains all the Window elements
#>
function Window
{
    param([ValidateNotNull()][Parameter(Mandatory=$true, Position=0)][String]$Title,
          [ValidateNotNull()][Parameter(Position=2)][String]$Description,
          [ValidateNotNull()][Parameter(Position=1)][Scriptblock]$ScriptBlock)

    if ((Get-PSCallStack)[2].Command -ne "Assistant")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg3
    }

    $HeaderWidth = $Title.Length * 10 - 20;
    
    $xaml = "<TabItem> "
    $xaml += "<TabItem.Header> "
    $xaml += "<TextBlock Text='$Title' Width='$HeaderWidth' Margin='4' /> "
    $xaml += "</TabItem.Header> "
    $xaml += "<Grid "
    $xaml += "HorizontalAlignment='Stretch' "
    $xaml += "VerticalAlignment='Top' "
    $xaml += ">"
    $xaml += "<Grid.ColumnDefinitions> "
    $xaml += "<ColumnDefinition Width='2*' /> "
    $xaml += "<ColumnDefinition Width='8*' /> "
    $xaml += "</Grid.ColumnDefinitions> "
    $xaml += "<Grid.RowDefinitions> "
    $xaml += "<RowDefinition Height='200' />"
    $xaml += "<RowDefinition Height='1*' /> "
    $xaml += "</Grid.RowDefinitions>"
    $xaml += "<Grid "
    $xaml += "Grid.Row='0' "
    $xaml += "Grid.Column='0' "
    $xaml += "Grid.ColumnSpan='2' "
    $xaml += ">"
    $xaml += "<Grid.ColumnDefinitions>"
    $xaml += "<ColumnDefinition Width='1*' />"
    $xaml += "<ColumnDefinition Width='5*' />"
    $xaml += "</Grid.ColumnDefinitions>"
    $xaml += "<Image "
    $xaml += "Grid.Column='0' "
    $xaml += "Source='$LogoPfad' "
    $xaml += "Height='Auto' "
    $xaml += "Width='Auto' "
    $xaml += "Margin='4' "
    $xaml += "Stretch='Fill' "
    $xaml += "/>"
    $xaml += "<TextBlock "
    $xaml += "Grid.Column='1' "
    $xaml += "Height='80' "
    $xaml += "Width='Auto' "
    $xaml += "FontFamily='Verdana' "
    $xaml += "FontSize='24' "
    $xaml += "Margin='4' "
    $xaml += "Padding='4' "
    $xaml += "Background='LightBlue' "
    $xaml += "Text='$Description' "
    $xaml += "/>"
    $xaml += "</Grid>"
    $xaml += "<StackPanel "
    $xaml += "Grid.Row='1' "
    $xaml += "Grid.Column='1' "
    $xaml += ">"
    $xaml += $ScriptBlock.Invoke()
    $xaml += "</StackPanel>"
    $xaml += "</Grid>"
    $xaml += "</TabItem>"
    $xaml
}

<#
 .Synopsis
 Inserts a head label with a big font size
 .Parameter Title
 The content of the label
#>
function HeadLabel
{
    param([String]$Title)
    # Check if the HeadLabel element is part of the window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg4
    }
    $Xaml = "<TextBlock "
    $Xaml += "Height='48' "
    $Xaml += "Width='Auto' "
    $Xaml += "FontSize='20' "
    $Xaml += "Margin='4' "
    $Xaml += "TextWrapping='Wrap' "
    $Xaml += "TextAlignment='Center' "
    $xaml += "HorizontalAlignment='Stretch' "
    $Xaml += "Background='LightYellow' "
    $Xaml += "Text='$Title' "
    $Xaml += "/>"
    $Xaml
}

<#
 .Synopsis
 Inserts a Next button
#>
function NextButton
{
    # Check if the Button element is part of the window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg5
    }
    $Xaml = "<Button "
    $Xaml += "x:Name='NextButton$NextButtonCount' "
    $Xaml += "HorizontalAlignment='Left' "
    $Xaml += "Width='200' "
    $Xaml += "Height='32' "
    $Xaml += "Margin='4' "
    $Xaml += "Content='_Weiter' "
    $Xaml += "/>"
    $Script:NextButtonCount++
    $Xaml
 }

<#
 .Synopsis
 Inserts a Back button
#>
function BackButton
{
    # Check if the Button element is part of the window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg6
    }
    $Xaml = "<Button "
    $Xaml += "x:Name='BackButton$BackButtonCount' "
    $Xaml += "Width='200' "
    $Xaml += "Height='32' "
    $Xaml += "Margin='80,4' "
    $Xaml += "HorizontalAlignment='Left' "
    $Xaml += "Content='_Zurück' "
    $Xaml += "/>"
    $Script:BackButtonCount++
    $Xaml
 }

<#
 .Synopsis
 Inserts a Textbox for text input
 .Parameter Name
 Name of the variable that contains the input
#>
function Textbox
{
    param([ValidateNotNullOrEmpty()]
          [Parameter(Mandatory=$true)][String]$Name,
          [Switch]$ChooseFile)

    # Check if the TextBox element is part of the window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg7
    }

    # Create a variable with the given name

    # Does the variable alreay exists?
    if (Get-Variable -Name $Name -ErrorAction SilentlyContinue)
    {
        $Script:ErrorFlag = $true
        Write-Error ($Msg.ErrorMsg8 -f $Name)
    }

    $v = New-Variable -Name $Name -Scope "Global" -PassThru
    $Script:WizardVariables += $v

    $Xaml = "<StackPanel "
    $Xaml += "Orientation='Horizontal' "
    $Xaml += "HorizontalAlignment='Left' "
    $Xaml += ">"
    $Xaml += "<TextBox "
    $Xaml += "x:Name='$Name' "
    $Xaml += "Width='400' "
    $Xaml += "Height='32' "
    $Xaml += "Margin='4' "
    $Xaml += "/>" 

    if ($ChooseFile)
    {
        $FileChooseButtonName = "$Name`_File"

        $Xaml += "<Button "
        $Xaml += "Name='$FileChooseButtonName' "
        $Xaml += "Width='40' Margin='4' "
        $Xaml += "Content='...' "
        $Xaml += "/>"
    }
    $Xaml += "</StackPanel>"
    $Xaml

}

<#
 .Synopsis
 Inserts a label
 .Parameter Text
 The content of the label
#>
function Label
{
    param([Parameter(Mandatory=$true, Position=1)][String]$Text,
          [Parameter(Position=2)][Int]$Width=400)

    # Check if the label element is part of the window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg9
    }
    $Xaml = "<Label "
    $Xaml += "Background='LightGray' "
    $Xaml += "HorizontalAlignment='Left' "
    $Xaml += "FontSize='16' "
    $Xaml += "Height='30' "
    $Xaml += "Width='$Width' "
    $Xaml += "Margin='4' "
    $Xaml += "Content='$Text' /> "
    $Xaml
}

<#
 .Synopsis
 Adds a multiple choice
 .Parameter Choices
 Each option as a string
 .Parameter Name
 Name of the variable that contains the selected element
#>
function Choice
{
    param([Parameter(Mandatory=$true, Position=1)][String[]]$Choices, 
          [Parameter(Mandatory=$true, Position=2)][String]$Name)

    # Check if the choice element is part of the window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg10
    }

    # Does variable exists?
    if (Get-Variable -Name $Name -ErrorAction SilentlyContinue)
    {
        $Script:ErrorFlag = $true
        Write-Error ($Err.ErrorMsg11 -f $Name)
    }

    # Variable will be pre set with first Choice Element
    # Necessary because otherwise the variable would be empty if no RadioButton will be selected
    $v = New-Variable -Name $Name -Scope "Global" -Value @($Choices[0]) -PassThru
    $Script:WizardVariables += $v

    # Add RadioButtons for each choice element
    $Xaml = "<GroupBox "
    $Xaml += "HorizontalAlignment='Left' "
    $Xaml += "VerticalContentAlignment='Stretch' "
    $Xaml += "Header='Mehrfachauswahl' "
    $Xaml += "Margin='4' "
    $Xaml += "Height='Auto' >"
    $Xaml += "<StackPanel> "
   
    $ChoiceIndex = 1
    foreach($Choice in $Choices)
    {
        $Xaml += "<RadioButton "
        $Xaml += "Name='$Name$ChoiceIndex' "
        if ($ChoiceIndex -eq 1) 
        {
            $Xaml += "IsChecked='true' "
        }
        $Xaml += "Content='$Choice' "
        $Xaml += "Margin='4,12' "
        $Xaml += "/>"
        $ChoiceIndex++
    }
    $Xaml += "</StackPanel> "
    $Xaml += "</GroupBox>"
    $Xaml

}

<#
 .Synopsis
 Inserts an OKButton for the Action
 .Parameter Action
 Scriptblock that the wizard should execute
 .Parameter Title
 Caption of the button
 .Parameter CloseWindow
 true if the button should close the window
#>
function OKButton
{
    param([Parameter(Mandatory=$true, Position=1)][ValidateNotNull()][ScriptBlock]$Action, 
          [Parameter(Position=2)][String]$Title="OK",
          [Parameter(Position=3)][Switch]$CloseWindow)

    # Only one OKButton allowed
    if ($Script:OKButtonCount -gt 1)
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg12
    }

    $Script:OKButtonCount++

    # Check if the OKButton part of the Window element
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw $Msg.ErrorMsg13
    }

    # Save action in variable
    $Script:SBOKButtonAction = $Action

    $Script:CloseWindow = $PSBoundParameters.ContainsKey("CloseWindow")

    $Xaml = "<Button "
    $Xaml += "x:Name='OKButton' "
    $Xaml += "Height='32' "
    $Xaml += "Width='160' "
    $Xaml += "Margin='8' "
    $Xaml += "Content='$Title' /> "
    $Xaml
}

