# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<#
    .NOTES
    ===================================================================================================================
    Created by:  Gary Blake - Senior Staff Solutions Architect
    Date:   2022-03-23
    Copyright 2021-2022 VMware, Inc.
    ===================================================================================================================
    
    .SYNOPSIS
    Configure vSphere/NSX/Supervisor Cluster for Developer Ready Infrastructure

    .DESCRIPTION
    The driConfigureSupervisorCluster.ps1 provides a single script to configure vSphere, NSX and enable the Supervisor
    Cluster as defined by the Developer Ready Infrastrucutre for VMware Cloud Foundation Validated Solution

    .EXAMPLE
    driConfigureSupervisorCluster.ps1 -sddcManagerFqdn sfo-vcf01.sfo.rainpole.io -sddcManagerUser administrator@vsphere.local -sddcManagerPass VMw@re1! -workbook F:\vvs\PnP.xlsx -filePath F:\vvs
    This example performs the configuration of vSphere, NSX and enable the Supervisor Cluster using the parameters provided within the Planning and Preparation Workbook
#>

Param (
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$sddcManagerFqdn,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$sddcManagerUser,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$sddcManagerPass,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$workbook,
    [Parameter (Mandatory = $true)] [ValidateNotNullOrEmpty()] [String]$filePath
)

Clear-Host; Write-Host ""

Start-SetupLogFile -Path $filePath -ScriptName $MyInvocation.MyCommand.Name
Write-LogMessage -Type INFO -Message "Starting the Process of Configuring vSphere / NSX / Supervisor Cluster on Developer Ready Infrastrucutre for VMware Cloud Foundation Validated Solution" -Colour Yellow
Write-LogMessage -Type INFO -Message "Setting up the log file to path $logfile"

Try {
    Write-LogMessage -Type INFO -Message "Checking Existance of Planning and Preparation Workbook: $workbook"
    if (!(Test-Path $workbook )) {
        Write-LogMessage -Type ERROR -Message "Unable to Find Planning and Preparation Workbook: $workbook, check details and try again" -Colour Red
        Break
    }
    else {
        Write-LogMessage -Type INFO -Message "Found Planning and Preparation Workbook: $workbook"
    }
    Write-LogMessage -Type INFO -Message "Checking a Connection to SDDC Manager: $sddcManagerFqdn"
    if (Test-VCFConnection -server $sddcManagerFqdn ) {
        Write-LogMessage -Type INFO -Message "Attempting to connect to VMware Cloud Foundation to Gather System Details"
        if (Test-VCFAuthentication -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass) {
            Write-LogMessage -Type INFO -Message "Gathering Details from SDDC Manager Inventory and Extracting Worksheet Data from the Excel Workbook"
            Write-LogMessage -type INFO -message "Opening the Excel Workbook: $Workbook"
            $pnpWorkbook = Open-ExcelPackage -Path $Workbook
            Write-LogMessage -type INFO -message "Checking Valid Planning and Prepatation Workbook Provided"
            if (($pnpWorkbook.Workbook.Names["vcf_version"].Value -ne "v4.3.x") -and ($pnpWorkbook.Workbook.Names["vcf_version"].Value -ne "v4.4.x")) {
                Write-LogMessage -type INFO -message "Planning and Prepatation Workbook Provided Not Supported" -colour Red 
                Break
            }

            $domainFqdn                         = $pnpWorkbook.Workbook.Names["region_ad_child_fqdn"].Value
            $wldSddcDomainName                  = $pnpWorkbook.Workbook.Names["wld_sddc_domain"].Value

            $kubSegmentName                     = $pnpWorkbook.Workbook.Names["k8s_mgmt_seg"].Value
            $wldTier1GatewayName                = $pnpWorkbook.Workbook.Names["wld_tier1_name"].Value
            $kubSegmentGatewayCIDR              = $pnpWorkbook.Workbook.Names["k8s_segment_gateway_ip_cidr"].Value
            $overlayTzName                      = "overlay-tz-" + $pnpWorkbook.Workbook.Names["wld_nsxt_vip_fqdn"].Value
            $wldTier0GatewayName                = $pnpWorkbook.Workbook.Names["wld_tier0_name"].Value
            $wldPrefixListName                  = $pnpWorkbook.Workbook.Names["k8s_ip_prefixlist"].Value
            $kubSegmentSubnetCidr               = $pnpWorkbook.Workbook.Names["k8s_segment_cidr"].Value
            $ingressSubnetCidr                  = $pnpWorkbook.Workbook.Names["k8s_ingress_pool_cidr"].Value
            $egressSubnetCidr                   = $pnpWorkbook.Workbook.Names["k8s_egress_pool_cidr"].Value
            $wldRouteMapName                    = $pnpWorkbook.Workbook.Names["k8s_ip_routemap"].Value
            $tagCategoryName                    = $pnpWorkbook.Workbook.Names["k8s_vcenter_category"].Value
            $tagName                            = $pnpWorkbook.Workbook.Names["k8s_vcenter_tag"].Value
            $spbmPolicyName                     = $pnpWorkbook.Workbook.Names["k8s_vcenter_storage_policy"].Value
            $contentLibraryName                 = $pnpWorkbook.Workbook.Names["k8s_vcenter_content_library"].Value
            $wmClusterName                      = $pnpWorkbook.Workbook.Names["wld_cluster"].Value
            $CommonName                         = $pnpWorkbook.Workbook.Names["k8s_cluster_endpoint_fqdn"].Value
            $Organization                       = $pnpWorkbook.Workbook.Names["ca_organization"].Value
            $OrganizationalUnit                 = $pnpWorkbook.Workbook.Names["ca_organization_unit"].Value
            $Country                            = $pnpWorkbook.Workbook.Names["ca_country"].Value
            $StateOrProvince                    = $pnpWorkbook.Workbook.Names["ca_state"].Value
            $Locality                           = $pnpWorkbook.Workbook.Names["ca_locality"].Value
            $AdminEmailAddress                  = $pnpWorkbook.Workbook.Names["ca_email_address"].Value
            $KeySize                            = $pnpWorkbook.Workbook.Names["ca_key_size"].Value
            $domainBindUser                     = $pnpWorkbook.Workbook.Names["child_svc_vsphere_ad_user"].Value
            $domainBindPass                     = $pnpWorkbook.Workbook.Names["child_svc_vsphere_ad_password"].Value
            $wmNamespaceName                    = $pnpWorkbook.Workbook.Names["k8s_namepsace"].Value
            $wmNamespaceEditUserGroup           = $pnpWorkbook.Workbook.Names["group_gg_kub_admins"].Value
            $wmNamespaceViewUserGroup           = $pnpWorkbook.Workbook.Names["group_gg_kub_readonly"].Value
            $licenseKey                         = $pnpWorkbook.Workbook.Names["esx_k8s_license"].Value
            $certificateRequestFile             = $filePath + "\supervisorCluster.csr"
            $certificateFile                    = $filePath + "\supervisorCluster.cer"

            $wmClusterInput = @{
                server = $sddcManagerFqdn
                user = $sddcManagerUser
                pass = $sddcManagerPass
                domain = $wldSddcDomainName
                cluster = $wmClusterName
                sizeHint = "Tiny"
                managementNetworkMode = "StaticRange"
                managementVirtualNetwork = $kubSegmentName
                managementNetworkStartIpAddress = $pnpWorkbook.Workbook.Names["k8s_mgmt_pool_start_ip"].Value
                managementNetworkAddressRangeSize = "5"
                managementNetworkGateway = $pnpWorkbook.Workbook.Names["k8s_segment_gateway_ip"].Value
                managementNetworkSubnetMask = $pnpWorkbook.Workbook.Names["k8s_segment_mask"].Value
                masterDnsName = $wmClusterName + "." + $domainFqdn
                masterNtpServers = @($pnpWorkbook.Workbook.Names["region_ntp1_server"].Value)
                masterDnsServers = @($pnpWorkbook.Workbook.Names["region_dns1_ip"].Value)
                contentLibrary = $contentLibraryName
                ephemeralStoragePolicy = $spbmPolicyName
                imageStoragePolicy = $spbmPolicyName
                masterStoragePolicy = $spbmPolicyName
                nsxEdgeCluster = $pnpWorkbook.Workbook.Names["wld_ec_name"].Value
                distributedSwitch = $pnpWorkbook.Workbook.Names["wld_vds_name"].Value
                podCIDRs = $pnpWorkbook.Workbook.Names["k8s_supervisor_cluster_pod_pool_cidr"].Value
                serviceCIDR = $pnpWorkbook.Workbook.Names["k8s_supervisor_cluster_service_pool_cidr"].Value
                externalIngressCIDRs = $ingressSubnetCidr
                externalEgressCIDRs = $egressSubnetCidr
                masterDnsSearchDomain = $pnpWorkbook.Workbook.Names["child_dns_zone"].Value
                workerDnsServers = @($pnpWorkbook.Workbook.Names["region_dns1_ip"].Value)
            }

            # Add a Network Segment for Tanzu to NSX-T Data Center
            Write-LogMessage -Type INFO -Message "Add a Network Segment for Tanzu to NSX-T Data Center"
            $StatusMsg = Add-NetworkSegment -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -SegmentName $kubSegmentName -ConnectedGateway $wldTier1GatewayName -Cidr $kubSegmentGatewayCIDR -TransportZone $overlayTzName -GatewayType Tier1 -SegmentType Overlay -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Add IP Prefix Lists to the Tier-0 Gateway for Tanzu to NSX-T Data Center
            Write-LogMessage -Type INFO -Message "Add IP Prefix Lists to the Tier-0 Gateway for Tanzu to NSX-T Data Center"
            $StatusMsg = Add-PrefixList -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -Tier0Gateway $wldTier0GatewayName -PrefixListName $wldPrefixListName -SubnetCIDR $kubSegmentSubnetCidr -ingressSubnetCidr $ingressSubnetCidr -egressSubnetCidr $egressSubnetCidr -GE "28" -LE "32" -Action PERMIT -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Create a Route Map on the Tier-0 Gateway for Tanzu to NSX-T Data Center
            Write-LogMessage -Type INFO -Message "Create a Route Map on the Tier-0 Gateway for Tanzu to NSX-T Data Center"
            $StatusMsg = Add-RouteMap -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -Tier0Gateway $wldTier0GatewayName -RouteMap $wldRouteMapName -PrefixListName $wldPrefixListName -Action PERMIT -ApplyPolicy:$True -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Assign a New Tag to the vSAN Datastore in vCenter Server
            Write-LogMessage -Type INFO -Message "Assign a New Tag to the vSAN Datastore in vCenter Server"
            $StatusMsg = Set-DatastoreTag -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -TagName $tagName -TagCategoryName $tagCategoryName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg"; $ErrorMsg = $null } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Create a Storage Policy that Uses the New vSphere Tag in vCenter Server
            Write-LogMessage -Type INFO -Message "Create a Storage Policy that Uses the New vSphere Tag in vCenter Server"
            $StatusMsg = Add-StoragePolicy -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -PolicyName $spbmPolicyName -TagName $tagName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg"; $ErrorMsg = $null } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Create a Subscribed Content Library for Tanzu in vCenter Server
            Write-LogMessage -Type INFO -Message "Create a Subscribed Content Library for Tanzu in vCenter Server"
            $StatusMsg = Add-ContentLibrary -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -ContentLibraryName $contentLibraryName -SubscriptionUrl "https://wp-content.vmware.com/v2/latest/lib.json" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg"; $ErrorMsg = $null } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Deploy a Supervisor Cluster for Developer Ready Infrastructure
            Write-LogMessage -Type INFO -Message "Deploy a Supervisor Cluster for Developer Ready Infrastructure"
            $StatusMsg = Enable-SupervisorCluster @wmClusterInput -RunAsync -SkipValidation $true -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg"; $ErrorMsg = '' } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Replace the Supervisor Cluster Kubernetes API Endpoint Certificate for Developer Ready Infrastructure
            Write-LogMessage -Type INFO -Message "Replace the Supervisor Cluster Kubernetes API Endpoint Certificate for Developer Ready Infrastructure"
            Write-LogMessage -Type INFO -Message "Generating the Supervisor Cluster CSR File"
            $StatusMsg = New-SupervisorClusterCSR -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -domain $wldSddcDomainName -cluster $wmClusterName -CommonName $CommonName -Organization $Organization -OrganizationalUnit $OrganizationalUnit -Country $Country -StateOrProvince $StateOrProvince -Locality $Locality -AdminEmailAddress $AdminEmailAddress -KeySize $Keysize -FilePath $certificateRequestFile -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg

            Write-LogMessage -Type INFO -Message "Requesting a Signed Certificate from the Microsoft Certificate Authority"
            $StatusMsg = Request-SignedCertificate -mscaComputerName $mscaComputerName -mscaName $mscaName -domainUsername $domainBindUser -domainPassword $domainBindPass -certificateTempalate $certificateTempalate -certificateRequestFile $certificateRequestFile -certificateFile $certificateFile -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            Write-LogMessage -Type INFO -Message "Installing the Supervisor Cluster Signed-Certificate"
            $StatusMsg = Add-SupervisorClusterCertificate -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -domain $wldSddcDomainName -cluster $wmClusterName -FilePath F:\vvs\supervisorCluster.cer -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
            
            # License the Supervisor Cluster for Developer Ready Infrastructure
            Write-LogMessage -Type INFO -Message "License the Supervisor Cluster for Developer Ready Infrastructure"
            $StatusMsg = Add-SupervisorClusterLicense -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -domain $wldSddcDomainName -Cluster $wmClusterName -LicenseKey $licenseKey -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Deploy a Supervisor Namespace for Developer Ready Infrastructure
            Write-LogMessage -Type INFO -Message "Deploy a Supervisor Namespace for Developer Ready Infrastructure"
            $StatusMsg = Add-Namespace -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -Cluster $wmClusterName -Namespace $wmNamespaceName -StoragePolicy $spbmPolicyName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg"; $ErrorMsg = '' } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Assign the Supervisor Namespace Roles to Active Directory Groups
            Write-LogMessage -Type INFO -Message "Assign the Supervisor Namespace Roles to Active Directory Groups"
            $StatusMsg = Add-NamespacePermission -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -sddcDomain $wldSddcDomainName -domain $domainFqdn -domainBindUser $domainBindUser -domainBindPass $domainBindPass -namespace $wmNamespaceName -principal $wmNamespaceEditUserGroup -role edit -type group -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
            $StatusMsg = Add-NamespacePermission -server $sddcManagerFqdn -user $sddcManagerUser -pass $sddcManagerPass -sddcDomain $wldSddcDomainName -domain $domainFqdn -domainBindUser $domainBindUser -domainBindPass $domainBindPass -namespace $wmNamespaceName -principal $wmNamespaceViewUserGroup -role view -type group -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }

            # Enable the Registry Service on the Supervisor Cluster for Developer Ready Infrastructure
            Write-LogMessage -Type INFO -Message "Enable the Registry Service on the Supervisor Cluster for Developer Ready Infrastructure"
            $StatusMsg = Enable-Registry -Server $sddcManagerFqdn -User $sddcManagerUser -Pass $sddcManagerPass -Domain $wldSddcDomainName -StoragePolicy $spbmPolicyName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -WarningVariable WarnMsg -ErrorVariable ErrorMsg
            if ( $StatusMsg ) { Write-LogMessage -Type INFO -Message "$StatusMsg" } if ( $WarnMsg ) { Write-LogMessage -Type WARNING -Message $WarnMsg -Colour Magenta } if ( $ErrorMsg ) { Write-LogMessage -Type ERROR -Message $ErrorMsg -Colour Red }
        }
    }
}
Catch {
    Debug-CatchWriter -object $_
}