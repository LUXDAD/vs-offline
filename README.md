# Visual Studio - Offline 
### Versions - 2017, 2019, 2022, 2026
### Editions - Enterprise, Professional, Community

Download from official Microsoft repositories and install or deploy in local machines without internet connection.

1. Download file "vsoffline.ps1" in folder "C:\vs-offline"
2. Run the script with the following command:
```powershell
pwsh -File "C:\vs-offline\vsoffline.ps1"
```
3. select version 
4. wait until the download is complete (80-85GB for 2026 Enterprise), 
	the files will be saved in "C:\vs-offline\Layout"
5. copy "C:\vs-offline\Layout" to local machine 
6. run the installer "C:\vs-offline\Layout\vs_setup.exe"
7. select features and workloads, then click "Install"