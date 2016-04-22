<#
 .Synopsis
 Eine supereinfache DSL für einen Assistenten
#>

Import-Module -Name D:\Pskurs\PoshWizard\Poshwizard.psm1 -Force

Assistant -Title "Modul anlegen" -ScriptBlock {

    Window -Title "Schritt 1" -Description "Willkommen" -ScriptBlock {
      HeadLabel "Willkommen zu diesem supercoolen Assistenten."

      NextButton
     
    }

    Window -Title "Schritt 2" -Description "Modulnamen festlegen" -ScriptBlock {
      HeadLabel "Leg den Modulnamen fest."

      Textbox -Name ModulName

      BackButton

      NextButton
     
    }

    Window -Title "Schritt 3" -Description "Auswahl einer Farbe" -ScriptBlock {

        Choice -Name "FarbAuswahl" -Choices "Rot", "Gelb", "Grün"

        BackButton

        NextButton
    }

    Window -Title "Schritt 4" -Description "Ps1-Datei auswählen" -ScriptBlock {

      HeadLabel "Auswahl der PS1-Datei"

      Textbox -Name Ps1Pfad -ChooseFile

      NextButton

    }

    Window -Title "Schritt 5" -Description "Fertig" -ScriptBlock {
      HeadLabel "Alle Angaben wurden erfasst."

      OKButton -Title "Modul anlegen" -CloseWindow -Action {
        if ($ModulName -ne $null -and (Test-Path -Path $Modulname -IsValid))
        {
            # md $Modulname -Force -Verbose
            Set-Content -Path $Ps1Pfad -Value $FarbAuswahl
        }
        else
        {
            Write-Warning "$Path ist kein gültiger Pfad"
        }
      }
     
    }

}

#$Assistant