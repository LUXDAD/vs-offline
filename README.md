# Visual Studio - Offline 
### Versions - 2017, 2019, 2022, 2026
### Editions - Enterprise, Professional, Community
#### Full Versions - select all features and workloads in installer

Download from official Microsoft repositories and install or deploy in local machines without internet connection.

1. Download file "vso.ps1" into folder "C:\vs-offline"
2. open Powershell as admin and run the script with the following command:
	a) if you have Windows Powershell installed, run:
```powershell
powershell -File "C:\vs-offline\vso.ps1"
```

	a) if you have Windows Powershell installed, run:
```powershell
powershell -File "C:\vs-offline\vso.ps1"
```
3. select version, efition, language 
4. wait until the download is complete (80-85GB for 2026 Enterprise), 
	the files will be saved in "C:\vs-offline\Layout"
5. copy "C:\vs-offline\Layout" to local machine 
6. run the installer "C:\vs-offline\Layout\vs_setup.exe"
7. select features and workloads, then click "Install"