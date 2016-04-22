<#
 .Synopsis
 Eine DSL für einen Assistenten
 .Notes
 Letzte Änderung: 22/4/2016
#>

# Hilfsklasse für das Auffinden von Controls

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
            // Holt alle logischen Kindelemente eines bestimmten Typs
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

            // Holt alle TextBoxen
            public static List<TextBox> GetTextboxes(Window w)
            {
                List<TextBox> textboxList = GetLogicalChildCollection<TextBox>(w);
                // Console.WriteLine("*** {0} TextBoxen gefunden. ***", textboxList.Count);
                return textboxList;
            }

            // Holt alle RadioButtons
            public static List<RadioButton> GetRadioButtons(Window w)
            {
                List<RadioButton> radioButtonList = GetLogicalChildCollection<RadioButton>(w);
                // Console.WriteLine("*** {0} RadioButtons gefunden. ***", radioButtonList.Count);
                return radioButtonList;
            }

        }
    }

'@

Add-Type -TypeDefinition $CSCode -Language CSharp `
 -ReferencedAssemblies PresentationCore, PresentationFramework, WindowsBase, System.Xaml

<#
 .Synopsis
 Legt einen Assistenten an
 .Parameter Title
 Die Überschrift
 .Parameter ScriptBlock
 Enthält die Elemente des Assistenten
 .Parameter Width
 Die Breite des Fensters
 .Parameter Height
 Die Höhe des Fensters
#>
function Assistant
{
    param([Parameter(Position=1)][String]$Title,
          [Parameter(Position=2)][Scriptblock]$Scriptblock,
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
    $Script:LogoPfad = (Join-Path -Path $PSScriptRoot -ChildPath "PowerShellLogo.png")

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

    $SBNextButton = {
        param($Sender, $EventArgs)
        # [System.Windows.MessageBox]::Show($CurrentTabIndex)
        [void]($Sender.Name -match "\w+(\d+)")
        $TabIndex = $Matches[1]
        $TabControl.SelectedIndex = $TabIndex
        $Script:CurrentTabIndex = $TabIndex
    }

    $SBBackButton = {
        param($Sender, $EventArgs)
        [void]($Sender.Name -match "\w+(\d+)")
        $TabIndex = [Int]$Matches[1]
        $TabIndex--
        $TabControl.SelectedIndex = $TabIndex
        $Script:CurrentTabIndex = $TabIndex
    }

    $SBTabSelectionChanged = {
        param($Sender, $EventArgs)
        $SB = {
             [System.Windows.MessageBox]::Show($Sender.SelectedItem.Header)
        }
        $Script:CurrentTabIndex = $Sender.SelectedIndex
        # Anzeigen einer MessageBox nicht so ohne weiteres möglich,
        # da sie die Nachrichtenverarbeitung blockiert?
        # $MainWin.Dispatcher.Invoke([Action]$SB, "Normal")
    }

    $SBTextBoxChanged = {
        # Aktuellen Wert der Textbox in gleichnamige Variable eintragen
        param($Sender, $EventArgs)
        $TBName = $Sender.Name
        Set-Variable -Name $TBName -Value $Sender.Text -Scope "Global"
    }

    $SBSelectedChanged = {
        param($Sender, $EventArgs)
        # Text des selektierten RadioButtons in die entsprechende Variable schreiben
        # Die Ziffer(n) am Ende abtrennen
        [void]($Sender.Name -match "^([a-z]+)(\d+)")
        $RadioName = $Matches[1]
        Set-Variable -Name $RadioName -Value $Sender.Content -Scope "Global"
    }
 
    $MainWin= [System.Windows.Markup.XamlReader]::Parse($Xaml)
    $TabControl = $MainWin.FindName("MainTabControl")
    $TabControl.add_SelectionChanged($SBTabSelectionChanged)

    # Alle NextButtons finden
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

    # Alle BackButtons finden
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

    # Alle TextBoxen mit ChangedEvent-Handler belegen
    $TextboxListe = [Poshwizard.WPFHelper]::GetTextboxes($MainWin)
    foreach($Tb in $TextboxListe)
    {
        $Tb.add_TextChanged($SBTextBoxChanged)
    }

    # Alle RadionButtons mit CheckedEvent-Handlern belegen
    $RadioButtonListe = [Poshwizard.WPFHelper]::GetRadioButtons($MainWin)
    foreach($Rb in $RadioButtonListe)
    {
        $Rb.add_Checked($SBSelectedChanged)
    }

 
    # OKButton-Action festlegen
    $OKButton = $MainWin.FindName("OKButton")

    # Gibt es einen OK-Button?
    if ($OKButton -eq $null)
    {
        $Script:ErrorFlag = $true
        Write-Error "Assistent muss mit OKButton-Element beendet werden."
    }

    $OKButton.add_click($Script:SBOKButtonAction)

    $SBClose = {
        if ($Script:CloseWindow)
        {
            $MainWin.Close()
        }
    }

    $OKButton.add_click($SBClose)

    if (!$Script:ErrorFlag)
    {
        [void]$MainWin.ShowDialog()
    }
    else
    {
        Write-Warning "*** Bitte erst die angezeigten Fehler beheben ***"
    }

    # Alle angelegten Variablen wieder löschen
    foreach($v in $Script:WizardVariables)
    {
        rm variable:"$($v.Name)"
    }

}

<#
 .Synopsis
 Legt ein einzelnes Fenster an
 .Parameter Title
 Die Überschrift
 .Parameter Description
 Überschrift für den Fensterinhalt
 .Parameter ScriptBlock
 Enthält die Elemente des Fensters
#>
function Window
{
    param([ValidateNotNull()][Parameter(Position=0)][String]$Title,
          [ValidateNotNull()][String]$Description,
          [ValidateNotNull()][Parameter(Position=1)][Scriptblock]$ScriptBlock)

    # Feststellen, ob es Teil von Assistant ist
    if ((Get-PSCallStack)[2].Command -ne "Assistant")
    {
        $Script:ErrorFlag = $true
        throw "Window muss Teil von Assistant sein"
    }

    $xaml = "<TabItem> "
    $xaml += "<TabItem.Header> "
    $xaml += "<TextBlock Text='$Title' Width='100' Margin='4' /> "
    $xaml += "</TabItem.Header> "
    $xaml += "<DockPanel "
    $xaml += " HorizontalAlignment='Stretch' "
    $xaml += ">"
    $xaml += "<Grid "
    $Xaml += "DockPanel.Dock='Top' "
    $xaml += ">"
    $xaml += "<Grid.ColumnDefinitions> "
    $xaml += "<ColumnDefinition Width='2*' /> "
    $xaml += "<ColumnDefinition Width='8*' /> "
    $xaml += "</Grid.ColumnDefinitions> "
    $xaml += "<Image "
    $Xaml += "DockPanel.Dock='Top' "
    $xaml += "Grid.Column='0' "
    $xaml += "Source='$LogoPfad' "
    $xaml += "Height='80' "
    $xaml += "Width='Auto' "
    $xaml += "Margin='4' "
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
    $xaml += "</Grid> "
    $xaml += $ScriptBlock.Invoke()
    $xaml += "</DockPanel>"
    $xaml += "</TabItem>"
    $xaml
}

<#
 .Synopsis
 Legt eine Kopfzeile für ein Fenster fest
 .Parameter Title
 Der Inhalt
#>
function HeadLabel
{
    param([String]$Title)
    # Feststellen, ob HeadLabel ein Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "HeadLabel muss Teil von Window sein"
    }
    $Xaml = "<TextBlock "
    $Xaml += "DockPanel.Dock='Top' "
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
 Fügt einen Weiter-Button ein
#>
function NextButton
{
    # Feststellen, ob der NextButton Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "NextButton muss Teil von Window sein"
    }
    $Xaml = "<Button "
    $Xaml += "x:Name='NextButton$NextButtonCount' "
    $Xaml += "DockPanel.Dock='Right' "
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
 Fügt einen Zurück-Button ein
#>
function BackButton
{
    # Feststellen, ob der BackButton Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "BackButton muss Teil von Window sein"
    }
    $Xaml = "<Button "
    $Xaml += "x:Name='BackButton$BackButtonCount' "
    $Xaml += "DockPanel.Dock='Left' "
    $Xaml += "Width='200' "
    $Xaml += "Height='32' "
    $Xaml += "Margin='80,4' "
    $Xaml += "HorizontalAlignment='Center' "
    $Xaml += "Content='_Zurück' "
    $Xaml += "/>"
    $Script:BackButtonCount++
    $Xaml
 }

<#
 .Synopsis
 Fügt Textfeld für die Eingabe ein
 .Parameter Name
 Der Name, über den der Inhalt angesprochen wird
#>

function Textbox
{
    param([ValidateNotNullOrEmpty()][String]$Name)

    # Feststellen, ob TextBox Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "TextBox muss Teil von Window sein"
    }

    # Variable für den Namen anlegen

    # Gibt es Variable bereits?
    if (Get-Variable -Name $Name -ErrorAction SilentlyContinue)
    {
        $Script:ErrorFlag = $true
        Write-Error "$Name für TextBox-Element bereits vergeben."
    }

    $v = New-Variable -Name $Name -Scope "Global" -PassThru
    $Script:WizardVariables += $v

    $Xaml = "<TextBox "
    $Xaml += "x:Name='$Name' "
    $Xaml += "DockPanel.Dock='Top' "
    $Xaml += "Width='400' "
    $Xaml += "Height='32' "
    $Xaml += "Margin='8' "
    $Xaml += "/>" 
    $Xaml

}

<#
 .Synopsis
 Fügt ein Bezeichnungsfeld ein
 .Parameter Text
 Der Inhalt des Bezeichnungsfeldes
#>
function Label
{
    param([Parameter(Position=1)][String]$Text,
          [Parameter(Position=2)][Int]$Width=400)

    # Feststellen, ob das Label Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "Label muss Teil von Window sein"
    }
    $Xaml = "<Label "
    $Xaml += "DockPanel.Dock='Top' "
    $Xaml += "Background='LightGray' "
    $Xaml += "FontSize='14' "
    $Xaml += "Width='$Width' "
    $Xaml += "Margin='8' "
    $Xaml += "Content='$Text' /> "
    $Xaml

}

<#
 .Synopsis
 Fügt eine Auswahl ein
 .Parameter Choices
 Die Auswahlpunkte als Texte
 .Parameter Name
 Der Name, über den die Auswahl angesprochen wird
#>
function Choice
{
    param([Parameter(Position=1)][String[]]$Choices, 
          [Parameter(Position=2)][String]$Name)

    # Feststellen, ob das Choice-Element Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "Choice muss Teil von Window sein"
    }

    # Gibt es Variable bereits?
    if (Get-Variable -Name $Name -ErrorAction SilentlyContinue)
    {
        $Script:ErrorFlag = $true
        Write-Error "$Name für Choice-Element bereits vergeben."
    }

    # Variable wird mit dem ersten Choice-Element vorbelegt
    # Wird kein RadioButton selektiert, wäre die Variable ansonsten leer
    $v = New-Variable -Name $Name -Scope "Global" -Value @($Choices[0]) -PassThru
    $Script:WizardVariables += $v

    # Für alle Choice-Elemente RadioButtons einfügen
    $Xaml = "<GroupBox "
    $Xaml += "DockPanel.Dock='Top' "
    $Xaml += "Header='Mehrfachauswahl' "
    $Xaml += "Margin='4' "
    $Xaml += "VerticalContentAlignment='Stretch' "
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
 Fügt einen OK-Button zum Abschluss ein
 .Parameter Action
 Die Befehle, die zum Abschluss ausgeführt werden sollen
 .Parameter Title
 Die Beschriftung
 .Parameter CloseWindow
 Bestimmt, ob das Fenster geschlossen wird
#>
function OKButton
{
    param([Parameter(Position=1)][ValidateNotNull()][ScriptBlock]$Action, 
          [Parameter(Position=2)][String]$Title="OK",
          [Parameter(Position=3)][Switch]$CloseWindow)

    # Es darf nur einen OKButton geben
    if ($Script:OKButtonCount -gt 1)
    {
        $Script:ErrorFlag = $true
        throw "OKButton darf nur einmal verwendet werden."
    }

    $Script:OKButtonCount++

    # Feststellen, ob der OKButton Teil von Window ist
    if ((Get-PSCallStack)[2].Command -ne "Window")
    {
        $Script:ErrorFlag = $true
        throw "OKButton muss Teil von Window sein"
    }

    # Action speichern
    $Script:SBOKButtonAction = $Action

    $Script:CloseWindow = $PSBoundParameters.ContainsKey("CloseWindow")

    $Xaml = "<Button "
    $Xaml += "x:Name='OKButton' "
    $Xaml += "DockPanel.Dock='Bottom' "
    $Xaml += "Height='32' "
    $Xaml += "Width='160' "
    $Xaml += "Margin='8' "
    $Xaml += "Content='$Title' /> "
    $Xaml
}

