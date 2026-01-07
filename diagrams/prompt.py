from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2, EKS
from diagrams.aws.general import Users
from diagrams.aws.management import Cloudwatch
from diagrams.aws.network import CloudFront, ELB, NATGateway, PrivateSubnet, PublicSubnet, Route53
from diagrams.aws.security import IAM, WAF
from diagrams.aws.storage import EBS, EFS, S3
from diagrams.generic.blank import Blank
from diagrams.onprem.vcs import Github

def main() -> None:

    # ... (Tus definiciones de colores y atributos siguen igual) ...
    edge_bg = "#E8F5E9"
    subnet_bg = "#FBF5FC"
    obs_traffic = "#607D8B"
    edge_traffic = "#2E7D32"
    backend_traffic = "#6A1B9A"
    mgmt_traffic = "#546E7A"
    color_aws_account = "#E91E63"  # El rosa/rojo del borde "Kelvin account"
    color_vpc_border = "#7C4DFF"   # El morado del borde "VPC"
    color_subnet_public_border = "#29B6F6"  # Azul para subred pública
    color_subnet_private_border = "#66BB6A"  # Verde para subred privada
    penwidth_border = "2.5"
    font_size = "17"

    graph_attr = {
        "dpi": "130", #AUmentado para mejor resolución
        "fontsize": "16",
        "bgcolor": "white",
        "pad": "0.5",
        "nodesep": "0.6", # Reducido ligeramente para agrupar verticalmente mejor
        "ranksep": "2", # AUMENTADO: Esto fuerza más separación horizontal global
        "splines": "ortho",
        "fontname": "Helvetica",
    }
    
    node_attr = { "fontsize": "14.7", "fontname": "Helvetica", "width": "1.4", "height": "1.2" }
    edge_attr = { "fontname": "Helvetica", "fontsize": "12.5" }

    with Diagram(
        "Arquitectura AWS (Kubernetes EKS)",
        filename="diagrams/arquitectura",
        outformat="png",
        show=False,
        direction="LR",
        graph_attr=graph_attr,
        node_attr=node_attr,
        edge_attr=edge_attr,
    ):
        users = Users("Usuarios")
        ci_cd = Github("CI/CD Pipeline")
        cloudwatch = Cloudwatch("CloudWatch")

        with Cluster("Edge", graph_attr={"style": "rounded", "bgcolor": "white", "pencolor": "black", "penwidth": penwidth_border}):
            route53 = Route53("Route 53")
            s3_mlflow = S3("S3 Artifacts")
            cloudfront = CloudFront("CloudFront")

        with Cluster("Seguridad", graph_attr={"style": "rounded", "bgcolor": "white", "pencolor": "black", "penwidth": penwidth_border}):
            waf = WAF("WAF")

        with Cluster("Cuenta Principal", graph_attr={"style": "rounded", "bgcolor": "white", "pencolor": color_aws_account, "penwidth": penwidth_border, "fontsize": font_size}):
            iam = IAM("IAM Admin")

            with Cluster("VPC", graph_attr={"style": "rounded", "bgcolor": "white", "pencolor": color_vpc_border, "penwidth": penwidth_border, "fontsize": font_size}):
                
                # --- AQUÍ ESTÁ EL CAMBIO PRINCIPAL ---
                # Definimos los nodos, pero NO los conectamos lógicamente aún.
                
                with Cluster("Subredes Públicas", graph_attr={"bgcolor": "white", "pencolor": color_subnet_public_border, "penwidth": penwidth_border, "fontsize": f"{int(font_size) - 1}"}):
                    # Al definirlos en este orden, Python los crea, pero Graphviz decide dónde ponerlos.
                    pub_subnet_icon = PublicSubnet("Subred Pública")
                    nat = NATGateway("NAT GW")
                    ingress = ELB("ALB / Ingress")
                    
                    # TRUCO 1: Forzar expansión horizontal dentro de este cluster
                    # Conectamos izquierda -> derecha con linea invisible
                    pub_subnet_icon - Edge(style="invis") - nat - Edge(style="invis") - ingress

                with Cluster("Subredes Privadas", graph_attr={"bgcolor": subnet_bg, "pencolor": color_subnet_private_border, "penwidth": penwidth_border, "fontsize": f"{int(font_size) - 1}"}):
                    priv_subnet_icon = PrivateSubnet("Subred Privada")
                    eks = EKS("EKS Cluster")
                    workers = EC2("Worker Nodes")
                    
                    # Almacenamiento (queremos que esté "al lado" o cerca de los workers)
                    ebs = EBS("EBS")
                    efs = EFS("EFS")

                    # TRUCO 2: Forzar expansión horizontal en la zona privada
                    # Hacemos que la subred apunte al EKS y el EKS a los Workers horizontalmente
                    priv_subnet_icon - Edge(style="invis") - eks - Edge(style="invis") - workers
                    
                    # TRUCO 3: Evitar que EBS y EFS se apilen demasiado verticalmente
                    # Forzamos que EBS esté a la izquierda de EFS (horizontal)
                    # O bien, dejamos que floten. Probemos forzar horizontalidad:
                    workers - Edge(style="invis") - ebs - Edge(style="invis") - efs

        # =====================
        # Conexiones Lógicas (Las líneas reales)
        # =====================
        
        # Flujo Usuarios
        users >> Edge(color=edge_traffic) >> route53
        route53 >> Edge(color=edge_traffic) >> cloudfront >> waf >> ingress
        # Ruta alternativa sin CDN
        route53 >> Edge(color=edge_traffic, style="dashed") >> ingress

        # Flujo Ingress -> EKS
        ingress >> Edge(color=backend_traffic) >> eks >> workers

        # Flujo Storage
        workers >> ebs
        workers >> efs
        workers >> s3_mlflow

        # Flujo Red/NAT
        workers >> Edge(color=mgmt_traffic) >> nat >> pub_subnet_icon

        # Flujo IAM
        ci_cd >> iam >> eks

        # Observabilidad
        # Usamos Cloudwatch conectado "invisiblemente" para alinearlo al final horizontalmente
        # o usamos dotted si queremos verlo.
        workers >> Edge(style="dotted", color=obs_traffic) >> cloudwatch

if __name__ == "__main__":
    main()