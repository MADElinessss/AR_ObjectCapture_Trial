//
//  ViewController.swift
//  ARstudy
//
//  Created by 신정연 on 2023/06/25.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.autoenablesDefaultLighting =  true
        
        makeAR()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 세션 구성 생성
        let configuration = ARImageTrackingConfiguration()
        
        // 사람 인식 활성화
        configuration.frameSemantics.insert(.personSegmentation)
        
        // 메인 번들의 "Cards" 그룹에서 참조 이미지 로드
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "Cards", bundle: Bundle.main) else {
            fatalError("참조 이미지를 로드하는 데 실패했습니다.")
        }
        
        // 추적할 참조 이미지 설정
        configuration.trackingImages = referenceImages
        
        // 추적할 이미지의 최대 개수 설정
        configuration.maximumNumberOfTrackedImages = 2
        
        // 세션 실행
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    //touch 인식
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //touch point -> unwrap
        if let location = touches.first?.location(in: self.view), let hit = sceneView.hitTest(location).first{
            //1.2x
            let increaseSize = SCNAction.scale(by: 1.2, duration: 1)
            let decreaseSize = SCNAction.scale(by: 0.8, duration: 1)
            let sizeSequence = SCNAction.sequence([increaseSize, decreaseSize])
            
            hit.node.runAction(sizeSequence)
        }
    }
    
    func makeAR() {
        print("makeAR()")
        // USDZ 파일 로드
        guard let modelURL = Bundle.main.url(forResource: "Ghost", withExtension: "usdz"),
              let model = try? SCNScene(url: modelURL, options: nil),
              let modelNode = model.rootNode.childNodes.first else {
            
            // USDZ 모델을 로드하는 데 실패한 경우 에러 메시지 표시
            let errorMessage = "USDZ 모델을 로드하는 데 실패했습니다."
            let alert = UIAlertController(title: "에러", message: errorMessage, preferredStyle: .alert)
            let okAction = UIAlertAction(title: "확인", style: .default, handler: nil)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            
            return
        }

        // ARAnchor 생성
        let anchor = ARAnchor(name: "LemonMeringuePie", transform: simd_float4x4())
        
        // SceneView에서 앵커를 추가하고 모델 노드를 표시
        sceneView.session.add(anchor: anchor)
        sceneView.scene.rootNode.addChildNode(modelNode)

        //자식노드로 makeNickName -> 닉네임이 머랭 따라다니게
        modelNode.addChildNode(makeNickName())
        addAnimation(node: modelNode)
    }

    func makeNickName() -> SCNNode {
        let text = SCNText(string : "Madeline", extrusionDepth: 2)
        //text color -> material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        text.materials = [material]
        
        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(x:0.02, y:0.02, z:0.02)
        node.position = SCNVector3(x: -0.2, y: 0.2, z: 0)
        
        sceneView.scene.rootNode.addChildNode(node)
        
        return node
    }
    
    
    func addAnimation(node: SCNNode){
        //rotateBy 회전축
        let rotateOneTime = SCNAction.rotateBy(x: 0, y: 0.0, z: 0, duration: 5)
        //계속 돌아라
        let actionForever = SCNAction.repeatForever(rotateOneTime)
        
        node.runAction(actionForever)
    }
}

extension ViewController: ARSCNViewDelegate {
    // renderer(_:nodeFor:)를 anchor에 따라 새로운 노드를 추가합니다
    // anchor: 화면에 감지된 이미지
    // 결과 값으로 3D객체(node)를 리턴합니다.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // 빈 노드를 생성시킵니다.
        let node = SCNNode()
        
        // 이미지를 추적해야 하므로 감지된 anchor를 ARImageAnchor로 형변환을 시켜줍니다.
        // 또한 imageAnchor.referenceImage.name로 접근하여 지금 인식되고 있는 사진의 이름도 알 수 있습니다.
        guard let imageAnchor = anchor as? ARImageAnchor else { return node }
        
        let planeNode = detectCard(at: imageAnchor)
        
        node.addChildNode(planeNode)
        
        // 감지된 사진의 이름을 갖고 모델을 만들어 준다.
        if let imageName = imageAnchor.referenceImage.name {
            makeModel(on: planeNode, name: imageName)
        }
        
        return node
    }
    func detectCard(at imageAnchor: ARImageAnchor) -> SCNNode {
        // 카드를 인식해야 하므로 감지된 카드의 크기를 입력해 준다.(하드코딩 할 필요 X)
        // 카드위에 3D객체 형상(plane)을 렌더링을 시킨다.
        let plane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width,
                             height: imageAnchor.referenceImage.physicalSize.height)
        
        // 투명하게 만들기
        plane.firstMaterial?.diffuse.contents = UIColor(white: 1.0, alpha: 0.5)
        
        // 뼈대 설정
        let planeNode = SCNNode(geometry: plane)
        
        // 이전까지는 plane이 수직으로 생성이 되므로 우리는 스티커에 맞게 90도로 눞여 줘야 한다.
        // eulerAngles은 라디안 각도를 표현하기 위함.
        planeNode.eulerAngles.x = -(Float.pi / 2)
        
        return planeNode
    }
    func makeModel(on planeNode: SCNNode, name: String) {
        switch name {
        case Card.Ghost.name:
            guard let ghostScene = SCNScene(named: Card.Ghost.assetLocation) else { return }
            guard let ghostNode = ghostScene.rootNode.childNodes.first else { return }
            
            // 생성된 3D 모델의 각도를 조정
            ghostNode.eulerAngles.x = Float.pi/2
            ghostNode.eulerAngles.z = -(Float.pi/2)
            
            planeNode.addChildNode(ghostNode)
            
        case Card.Squidward.name:
            guard let squidwardScene = SCNScene(named: Card.Squidward.assetLocation) else { return }
            guard let squidwardNode = squidwardScene.rootNode.childNodes.first else { return }
            
            // 생성된 3D 모델의 각도와 위치를 조정
            squidwardNode.eulerAngles.x = Float.pi/2
            squidwardNode.position.z = -(squidwardNode.boundingBox.min.y * 6)/1000
            
            planeNode.addChildNode(squidwardNode)
            
        default: break
        }
    }
}

enum Card {
    case Ghost
    case Squidward
    
    var name: String {
        switch self {
        case .Ghost: return "Ghost"
        case .Squidward: return "Squidward"
        }
    }
    
    var assetLocation: String {
        switch self {
        case .Ghost:
            return "art.scnassets/Ghost.scn"
        case .Squidward:
            return "art.scnassets/Squidward.scn"
        }
    }
}


