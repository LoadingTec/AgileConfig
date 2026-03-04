import { getAppVer } from "@/utils/system";
import { GithubOutlined } from "@ant-design/icons"
import React from "react"

const LayoutFooter : React.FC =()=>{
    return (
        <div style={{
          display:'flex',
          justifyContent: 'center',
          marginBottom: '10px',
          color: '#bfbfbf'
        }}>
          v
          { getAppVer()}
          &nbsp;&nbsp;  
          <a title={'AKO Config Center:' + getAppVer()} href="#" style={{color:'#bfbfbf'}}>@<GithubOutlined/> </a>
          &nbsp; Powered by AKO R&D
        </div>
      )
}

export default LayoutFooter;