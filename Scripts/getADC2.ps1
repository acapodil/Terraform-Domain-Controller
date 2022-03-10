
    try{ 
        Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/acapodil/Azure-Virtual-Desktop/main/Scripts/install.ps1'))

    }
    catch{
        Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/acapodil/Azure-Virtual-Desktop/main/Scripts/install.ps1'))

    }


     try{ 
            choco install azure-ad-connect -yes --ignore-checksums

    }
    catch{
            choco install azure-ad-connect -yes --ignore-checksums

    }



    exit 0